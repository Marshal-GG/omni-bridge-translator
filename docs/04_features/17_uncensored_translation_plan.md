#17—UncensoredTranslationPlan

Thisdocumentprovidesacomprehensive,step-by-stepguidetoimplementingthe"Uncensored"translationtoggleinOmniBridge.ThechangesspantheFlutterfrontend(forUIandstatemanagement)andthePythonbackend(formodelconfiguration).

---

##Part1:FlutterFrontendChanges

###1.Update`AppSettings`Entity
**File:**`lib/features/settings/domain/entities/app_settings.dart`

-Add`finalboolisUncensored;`tothe`AppSettings`class.
-Updatetheconstructortoinclude`requiredthis.isUncensored`.
-In`AppSettings.initial()`,set`isUncensored:false`.
-In`copyWith()`,add`bool?isUncensored`.
-Update`fromJson()`and`toJson()`tohandlethe`isUncensored`key.
-Update`props`for`Equatable`compatibility.

###2.UpdateSettingsBLoCEvents
**File:**`lib/features/settings/presentation/blocs/settings_event.dart`

-Update`UpdateTempSettingEvent`:Add`finalbool?isUncensored`andupdatetheconstructorand`props`.
-Update`SyncTempSettingsEvent`:Add`finalboolisUncensored`andupdatetheconstructorand`props`.

###3.UpdateSettingsBLoCLogic
**File:**`lib/features/settings/presentation/blocs/settings_bloc.dart`

-In`_onSyncTempSettings`,add`isUncensored:event.isUncensored`tothe`copyWith`callon`state.settings`.
-In`_onUpdateTempSetting`,add`isUncensored:event.isUncensored??state.settings.isUncensored`tothe`copyWith`callon`state.settings`.

###4.UpdateTranslationState
**File:**`lib/features/translation/presentation/blocs/translation_state.dart`

-Add`finalboolactiveIsUncensored;`to`TranslationState`.
-In`TranslationState.initial()`,set`activeIsUncensored:false`.
-Update`copyWith`and`props`.

###5.UpdateTranslationApplyEvent
**File:**`lib/features/translation/presentation/blocs/translation_event.dart`

-Update`ApplySettingsEvent`:Add`finalboolisUncensored`andupdateconstructorand`props`.

###6.UpdateTranslationBLoCLogic
**File:**`lib/features/translation/presentation/blocs/translation_bloc.dart`

-In`_onLoadSettings`,extract`isUncensored`fromsettings:
```dart
activeIsUncensored:settings.isUncensored,
```
-In`_onApplySettings`,extract`isUncensored`andpassitto`updateTranslationSettingsUseCase`and`syncSettingsUseCase`.
-In`_onToggleRunning`,pass`state.activeIsUncensored`to`startTranslationUseCase`.

###7.UpdateUseCases&WebSocketClient
**Files:**
-`lib/features/translation/domain/usecases/update_translation_settings_usecase.dart`
-`lib/features/translation/domain/usecases/start_translation_usecase.dart`
-`lib/features/translation/data/datasources/translation_websocket_client.dart`

-Update`call()`methodsinbothusecasestoincludean`isUncensored`parameter.
-Update`TranslationWebsocketClient`:
-Addaprivatefield`bool_isUncensored=false;`.
-Update`start()`and`updateSettings()`toset`_isUncensored`.
-In`_sendStartPayload()`andtheJSONpayloadin`updateSettings()`,add`'is_uncensored':_isUncensored`.

###8.UpdateSettingsUI
**File:**`lib/features/settings/presentation/screens/settings_screen.dart`

-Inthe"Translation"tab,adda`SwitchListTile`forthe"Uncensored"setting.
-Implementthewarningdialoginthe`onChanged`callback:
```dart
onChanged:(boolvalue)async{
if(value){
finalconfirmed=awaitshowDialog<bool>(
context:context,
builder:(context)=>AlertDialog(
backgroundColor:constColor(0xFF1E1E1E),
title:constText('EnableUncensoredMode?',style:TextStyle(color:Colors.white)),
content:constText(
'Thiswilldisableprofanityfiltersandsafetyguardrails.Translationswillberawandmaycontainoffensivecontent.',
style:TextStyle(color:Colors.white70),
),
actions:[
TextButton(
onPressed:()=>Navigator.pop(context,false),
child:constText('Cancel',style:TextStyle(color:Colors.tealAccent)),
),
TextButton(
onPressed:()=>Navigator.pop(context,true),
child:constText('Enable',style:TextStyle(color:Colors.redAccent)),
),
],
),
);
if(confirmed==true&&mounted){
context.read<SettingsBloc>().add(UpdateTempSettingEvent(isUncensored:true));
}
}else{
context.read<SettingsBloc>().add(UpdateTempSettingEvent(isUncensored:false));
}
},
```

---

##Part2:PythonBackendChanges

###1.UpdateConfigHandler
**File:**`server/src/network/handlers/config_handler.py`

-In`update_settings`,extract`new_uncensored=msg.get("is_uncensored",self.ctx.config["is_uncensored"])`.
-Update`has_changed`booleantoinclude`self.ctx.config["is_uncensored"]!=new_uncensored`.
-Update`self.ctx.config.update({"is_uncensored":new_uncensored})`.

###2.UpdateOrchestrator
**File:**`server/src/pipeline/orchestrator.py`

-Ensure`InferenceOrchestrator`storesthe`is_uncensored`flagfromtheconfiguration.
-In`_init_models`,propagatethisflagtothemodelinstances.

###3.UpdateRivaASRModel
**File:**`server/src/models/asr/riva_asr.py`

-Update`make_config()`:
```python
profanity_filter=notself.is_uncensored
```

###4.UpdateLlamaTranslationModel
**File:**`server/src/models/translation/llama_translation.py`

-Update`translate()`touseadifferentsystempromptwhen`is_uncensored`is`True`.
-**UncensoredPromptExample:**
>"Translatethefollowingspokentextfrom{source_lang}to{target_lang}.Providearaw,literal,andfaithfultranslation.Donotcensor,filter,orreplaceanycontent,includingprofanityorsensitivelanguage.Outputonlythetranslatedtext."

---

##Part3:VerificationSteps

1.**StateCheck**:Verifythetogglestatepersistsaftersavingandclosingtheapp.
2.**BackendSync**:Confirmthatthebackendreceivesthe`is_uncensored`flagthroughserverlogs.
3.**ASRTest**:TestwithspokenprofanitywhileRivaisselected;ensureittranscribesliterallywithoutreplacement.
4.**TranslationTest**:TestwithLlama-basedtranslationofknownsensitivephrases.
