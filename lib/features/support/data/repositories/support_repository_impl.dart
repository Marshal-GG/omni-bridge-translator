import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failures.dart';
import '../../../usage/domain/repositories/usage_repository.dart';
import '../datasources/support_local_datasource.dart';
import '../datasources/support_remote_datasource.dart';
import '../../domain/entities/feedback_ticket.dart';
import '../../domain/entities/support_link.dart';
import '../../domain/entities/system_snapshot.dart';
import '../../domain/entities/support_message.dart';
import '../../domain/repositories/i_support_repository.dart';

class SupportRepositoryImpl implements ISupportRepository {
  final ISupportLocalDataSource localDataSource;
  final ISupportRemoteDataSource remoteDataSource;
  final UsageRepository usageRepository;
  final FirebaseAuth firebaseAuth;
  final DeviceInfoPlugin deviceInfo;

  SupportRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.usageRepository,
    required this.firebaseAuth,
    required this.deviceInfo,
  });

  @override
  Future<Either<Failure, List<SupportLink>>> getSupportLinks() async {
    try {
      final links = await localDataSource.getSupportLinks();
      return Right(links);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SystemSnapshot>> getSystemSnapshot() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final user = firebaseAuth.currentUser;
      final quotaStatus = usageRepository.currentQuotaStatus;

      String osInfo = 'Unknown';
      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        osInfo = 'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion} (Build ${windowsInfo.buildNumber})';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        osInfo = 'macOS ${macInfo.osRelease}';
      }

      final remainingQuota = quotaStatus == null ? 0 : quotaStatus.dailyLimit - quotaStatus.dailyTokensUsed;

      return Right(SystemSnapshot(
        osVersion: osInfo,
        appVersion: packageInfo.version,
        subscriptionTier: quotaStatus?.tier ?? 'Free',
        remainingQuota: remainingQuota,
        userEmail: user?.email ?? 'anonymous',
      ));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> submitFeedback(FeedbackTicket ticket, List<File> attachments) async {
    try {
      final user = firebaseAuth.currentUser;
      final userId = user?.uid ?? 'anonymous';

      // 1. Upload attachments if any
      List<String> attachmentUrls = [];
      if (attachments.isNotEmpty) {
        attachmentUrls = await remoteDataSource.uploadAttachments(attachments, userId);
      }

      // 2. Create updated ticket with URLs
      final updatedTicket = FeedbackTicket(
        id: ticket.id,
        userId: userId,
        type: ticket.type,
        status: TicketStatus.open,
        subject: ticket.subject,
        message: ticket.message,
        lastMessage: ticket.message,
        systemSnapshot: ticket.systemSnapshot,
        attachmentUrls: attachmentUrls,
        timestamp: ticket.timestamp,
        updatedAt: DateTime.now(),
      );

      // 3. Submit to Firestore
      await remoteDataSource.submitFeedbackTicket(updatedTicket);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FeedbackTicket>>> getTicketHistory() async {
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) return const Left(ServerFailure('User not authenticated'));

      final tickets = await remoteDataSource.getTickets(user.uid);
      return Right(tickets);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<SupportMessage>>> getTicketMessages(String ticketId) {
    return remoteDataSource.getTicketMessages(ticketId).map(
          (messages) => Right<Failure, List<SupportMessage>>(messages),
        ).handleError((e) {
          return Left<Failure, List<SupportMessage>>(ServerFailure(e.toString()));
        });
  }

  @override
  Future<Either<Failure, Unit>> sendSupportMessage(String ticketId, SupportMessage message, {List<File> attachments = const []}) async {
    try {
      final user = firebaseAuth.currentUser;
      final userId = user?.uid ?? 'anonymous';

      final updatedMessage = SupportMessage(
        id: message.id,
        senderId: message.senderId.isEmpty ? userId : message.senderId,
        senderType: message.senderType,
        text: message.text,
        attachmentUrls: message.attachmentUrls,
        timestamp: message.timestamp,
      );

      await remoteDataSource.sendSupportMessage(ticketId, updatedMessage, attachments: attachments);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
