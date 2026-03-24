<!--
Copyright(c)2026OmniBridge.Allrightsreserved.

LicensedunderthePERSONALSTUDY&LEARNINGLICENSEv1.0.
Commercialuseandpublicredistributionofmodifiedversionsarestrictlyprohibited.
SeetheLICENSEfileintheprojectrootforfulllicenseterms.
-->

#18—SupportFeatureGuide

Thisdocumentdescribesthe`support`featuremodule—anintegratedhelpdeskthatprovidesuserswithreal-timechatsupport,tickethistory,andautomatedsystemdiagnosis.

##TableofContents
1.[Overview](#1-overview)
2.[Architecture](#2-architecture)
3.[DomainLayer](#3-domain-layer)
4.[DataLayer](#4-data-layer)
5.[PresentationLayer](#5-presentation-layer)
6.[SystemSnapshots](#6-system-snapshots)

---

##1.Overview

The`support`featureallowsuserstocommunicatewiththeOmniBridgesupportteamdirectlywithintheapplication.ItincludesaWhatsApp-stylechatinterface,ticketmanagement,andatooltogenerateandsendencryptedsystem"snapshots"forrapidtroubleshooting.

**Featurelocation**:`lib/features/support/`

---

##2.Architecture

```
lib/features/support/
├──domain/
│├──entities/#Ticket,Message,Snapshot
│├──repositories/#ISupportRepository(abstract)
│└──usecases/#SendSupportMessage,GetTicketHistory,etc.
├──data/
│├──datasources/#SupportRemoteDataSource,SupportLocalDataSource
│└──repositories/#SupportRepositoryImpl
└──presentation/
├──blocs/#SupportBloc,Events,States
├──screens/#SupportScreen,TicketDetailsScreen
└──widgets/#ChatBubble,TicketListTile,SnapshotPreview
```

---

##3.DomainLayer

###KeyUseCases
-**`SendSupportMessage`**:Dispatchesanewmessagetoanactiveticket.
-**`GetTicketHistory`**:Fetchesthelistofallpastandcurrentsupportrequests.
-**`GetSystemSnapshot`**:Gathersnon-PIIsystemdata(OSversion,applogs,serverstatus)fordebugging.
-**`SubmitFeedback`**:Allowsuserstosendquickratingsorcommentswithoutopeningaformalticket.

---

##4.DataLayer

###`SupportRemoteDataSource`
**File**:`lib/features/support/data/datasources/support_remote_datasource.dart`
CommunicateswiththeSupportbackend(FirebaseFirestoreforticketingandaRESTAPIformessagedelivery).

###`SupportLocalDataSource`
**File**:`lib/features/support/data/datasources/support_local_datasource.dart`
Handleslocalpersistenceofdraftmessagesandacacheofthelast10supportticketsforofflineviewing.

---

##5.PresentationLayer

###BLoC
**Directory**:`lib/features/support/presentation/blocs/`
Managesthereal-timestateofthechat.Itlistensfornewmessagearrivesviaastreamfromtherepositoryandhandlesthepaginationoftickethistory.

###DesignAesthetic
The`support`featureutilizes**Glassmorphism**andthe**OmniEther**designsystem.
-**MainAccent**:`primary`(#bd9dff)to`primary_dim`(#8a4cfc)gradients.
-**Layout**:Split-viewdashboardfordesktop,ensuringintuitivenavigationbetweendifferentsupportthreads.

---

##6.SystemSnapshots

Oneoftheuniquecapabilitiesofthe`support`featureisthe**SystemSnapshot**.Whenauserreportsabug:
1.The`GetSystemSnapshotUseCase`istriggered.
2.Itcapturesthecontentsof`PythonServerManager`logsandcoreappsettings.
3.Thedataisbundled,anonymized(PIIstripped),andattachedtotheticketasaJSONpayloadforthesupportteam.

---

##RelatedDocs

-[05——FlutterArchitecture](../02_architecture/05_flutter_architecture.md)—Feature-drivenstructureandBLoCreference
-[07——DatabaseSchema](../02_architecture/07_database_schema.md)—TicketingschemadetailsinFirestore
-[13——NewScreenSetupGuide](../03_guides/13_new_screen_setup_guide.md)—UI/UXpatternreference
