/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { GestureShareModel } from '../gis/GestureShareModel';
import { initPreferences, APP_THEME_MODE_KEY, THEME_MODE_DARK, THEME_MODE_LIGHT } from '../model/AppPreferences';
import { HuaweiAuthManager } from '../utils/HuaweiAuthManager';
import { ProcessingHistoryManager } from '../utils/ProcessingHistoryManager';
import { PublicDataDirectoryManager } from '../utils/PublicDataDirectoryManager';

const DOMAIN = 0x0000;
const TRANSPARENT_SYSTEM_BAR_COLOR = '#00000000';
const SYSTEM_BAR_CONTENT_COLOR = '#FFFFFFFF';
const CLEAN_WINDOW_BACKGROUND_COLOR = '#FFFFFF';
const IMMERSIVE_WINDOW_STATUS_KEY = 'gnImmersiveWindowStatus';
const EXTERNAL_FILE_URI_KEY = 'gnExternalFileUri';
const IMMERSIVE_WINDOW_PENDING_STATUS = '沉浸窗口：等待窗口初始化';
const IMMERSIVE_WINDOW_APPLYING_STATUS = '沉浸窗口：正在应用';
const IMMERSIVE_WINDOW_READY_STATUS = '沉浸窗口：已启用';
const IMMERSIVE_WINDOW_FAILED_STATUS = '沉浸窗口：主窗口不可用';
const WINDOW_CLOSE_REQUEST_KEY = 'gnWindowCloseRequestRevision';

export default class EntryAbility extends UIAbility {
  private mainWindowStage: window.WindowStage | undefined = undefined;
  private windowCloseGuardRegistered: boolean = false;
  private windowCloseGuardCallback: () => Promise<boolean> = (): Promise<boolean> => {
    let revision: number | undefined = AppStorage.get<number>(WINDOW_CLOSE_REQUEST_KEY);
    AppStorage.setOrCreate<number>(WINDOW_CLOSE_REQUEST_KEY, revision === undefined ? 1 : revision + 1);
    return Promise.resolve(true);
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initPreferences(this.context);
    ProcessingHistoryManager.getInstance().init(this.context);
    HuaweiAuthManager.getInstance().setContext(this.context);
    HuaweiAuthManager.getInstance().init();
    new PublicDataDirectoryManager().prepare(this.context.filesDir);
    AppStorage.setOrCreate<number>(WINDOW_CLOSE_REQUEST_KEY, 0);
    this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_PENDING_STATUS);
    this.captureExternalFileUri(want);
    this.handleShareData(want);
    this.applyStoredColorMode();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private applyStoredColorMode(): void {
    let themeMode: number | undefined = AppStorage.get<number>(APP_THEME_MODE_KEY);
    try {
      if (themeMode === THEME_MODE_DARK) {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (themeMode === THEME_MODE_LIGHT) {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    GestureShareModel.getInstance(this.context).stopListening();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.mainWindowStage = windowStage;
    this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_APPLYING_STATUS);

    this.enableWindowRectAutoSave(windowStage);
    this.applyImmersiveWindow(windowStage);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      this.applyImmersiveWindow(windowStage);
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Succeeded in loading the content.');
    });
  }

  private enableWindowRectAutoSave(windowStage: window.WindowStage): void {
    try {
      let promise = windowStage.setWindowRectAutoSave(true);
      promise.then(() => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in setting window rect auto-save.');
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag',
          'Failed to set window rect auto-save. Cause code: %{public}s, message: %{public}s',
          String(err.code), err.message);
      });
    } catch (exception) {
      hilog.error(DOMAIN, 'testTag',
        'Failed to set window rect auto-save. Cause code: %{public}s, message: %{public}s',
        String((exception as BusinessError).code), (exception as BusinessError).message);
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
    this.captureExternalFileUri(want);
    this.handleShareData(want);
    this.reapplyImmersiveWindow('new want');
  }

  private captureExternalFileUri(want: Want): void {
    let allUrisParam: string | undefined = want.parameters?.['geonesttool_all_uris'] as string;
    if (allUrisParam !== undefined && allUrisParam.length > 0) {
      AppStorage.setOrCreate<string>(EXTERNAL_FILE_URI_KEY, allUrisParam);
      hilog.info(DOMAIN, 'testTag', 'Captured geonesttool all URIs.');
      return;
    }

    let uri = want.uri;
    if (uri !== undefined && uri.length > 0) {
      AppStorage.setOrCreate<string>(EXTERNAL_FILE_URI_KEY, uri);
      hilog.info(DOMAIN, 'testTag', 'Captured external file uri.');
    } else {
      AppStorage.setOrCreate<string>(EXTERNAL_FILE_URI_KEY, '');
    }
  }

  private async handleShareData(want: Want): Promise<void> {
    try {
      let shareData: systemShare.SharedData = await systemShare.getSharedData(want);
      let records: systemShare.SharedRecord[] = shareData.getRecords();
      if (records.length === 0) {
        return;
      }

      hilog.info(DOMAIN, 'testTag', 'handleShareData: received %{public}d records', records.length);

      let firstUri: string = '';
      for (let i: number = 0; i < records.length; i++) {
        let record: systemShare.SharedRecord = records[i];
        if (record.uri !== undefined && record.uri.length > 0) {
          if (firstUri.length === 0) {
            firstUri = record.uri;
          }
          hilog.info(DOMAIN, 'testTag', 'Shared file URI: %{public}s', record.uri);
        }
      }

      if (firstUri.length > 0) {
        AppStorage.setOrCreate<string>(EXTERNAL_FILE_URI_KEY, firstUri);
        hilog.info(DOMAIN, 'testTag', 'Stored shared file URI to AppStorage');
      }
    } catch (e) {
      hilog.error(DOMAIN, 'testTag', 'handleShareData error: %{public}s', (e as BusinessError).message);
    }
  }

  private reapplyImmersiveWindow(reason: string): void {
    if (this.mainWindowStage === undefined) {
      this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_FAILED_STATUS);
      return;
    }
    this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_APPLYING_STATUS);
    hilog.info(DOMAIN, 'testTag', 'Reapply immersive window: %{public}s', reason);
    this.applyImmersiveWindow(this.mainWindowStage);
  }

  private async applyImmersiveWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      let mainWindow: window.Window = windowStage.getMainWindowSync();
      let systemBarProperties: window.SystemBarProperties = {
        statusBarColor: TRANSPARENT_SYSTEM_BAR_COLOR,
        navigationBarColor: TRANSPARENT_SYSTEM_BAR_COLOR,
        statusBarContentColor: SYSTEM_BAR_CONTENT_COLOR,
        navigationBarContentColor: SYSTEM_BAR_CONTENT_COLOR,
        isStatusBarLightIcon: true,
        isNavigationBarLightIcon: true,
        enableStatusBarAnimation: false,
        enableNavigationBarAnimation: false
      };

      mainWindow.setWindowBackgroundColor(CLEAN_WINDOW_BACKGROUND_COLOR);
      await this.setLayoutFullScreen(mainWindow);
      await this.setSystemBarProperties(mainWindow, systemBarProperties);
      await this.hideSystemBars(mainWindow);
      await this.hideNavigationIndicator(mainWindow);
      this.configureTitleBar(mainWindow);
      this.setWindowLimits(mainWindow);
      this.registerWindowCloseGuard(mainWindow);
      this.enableDragReceive(mainWindow);
      this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_READY_STATUS);
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Window immersive mode applied.');
    } catch (err) {
      this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_FAILED_STATUS);
      hilog.error(DOMAIN, 'testTag', 'Failed to get main window. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private configureTitleBar(mainWindow: window.Window): void {
    try {
      mainWindow.setWindowTitleButtonVisible(true, true, true);
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'setWindowTitleButtonVisible not supported: %{public}s', String(err));
    }
    try {
      let style: window.DecorButtonStyle = {
        buttonBackgroundSize: 28,
        spacingBetweenButtons: 12,
        closeButtonRightMargin: 20
      };
      mainWindow.setDecorButtonStyle(style);
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'setDecorButtonStyle not supported: %{public}s', String(err));
    }
  }

  private setWindowLimits(mainWindow: window.Window): void {
    try {
      let limits: window.WindowLimits = {
        minWidth: 800,
        minHeight: 500,
        maxWidth: 3840,
        maxHeight: 2160
      };
      mainWindow.setWindowLimits(limits).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in setting window limits.');
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag',
          'Failed to set window limits. Cause code: %{public}s, message: %{public}s',
          String(err.code), err.message);
      });
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'setWindowLimits not supported: %{public}s', String(err));
    }
  }

  private registerWindowCloseGuard(mainWindow: window.Window): void {
    if (this.windowCloseGuardRegistered) {
      return;
    }
    try {
      mainWindow.on('windowWillClose', this.windowCloseGuardCallback);
      this.windowCloseGuardRegistered = true;
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'windowWillClose guard unavailable: %{public}s', String(err));
    }
  }

  private enableDragReceive(targetWindow: window.Window): void {
    try {
      targetWindow.setReceiveDragEventEnabled(true).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Drag receive enabled.');
      }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, 'testTag',
          'Failed to enable drag receive. Cause code: %{public}s, message: %{public}s',
          String(err.code), err.message);
      });
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'setReceiveDragEventEnabled not supported: %{public}s', String(err));
    }
  }

  private async setLayoutFullScreen(mainWindow: window.Window): Promise<void> {
    try {
      await mainWindow.setWindowLayoutFullScreen(true);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set fullscreen layout. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async setSystemBarProperties(mainWindow: window.Window,
    systemBarProperties: window.SystemBarProperties): Promise<void> {
    try {
      await mainWindow.setWindowSystemBarProperties(systemBarProperties);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set system bar properties. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async hideSystemBars(mainWindow: window.Window): Promise<void> {
    try {
      let hiddenBars: Array<'status' | 'navigation'> = [];
      await mainWindow.setWindowSystemBarEnable(hiddenBars);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to hide system bars. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async hideNavigationIndicator(mainWindow: window.Window): Promise<void> {
    try {
      await mainWindow.setSpecificSystemBarEnabled('navigationIndicator', false, false);
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'Navigation indicator control is not supported. Cause: %{public}s',
        JSON.stringify(err));
    }
  }

  private setImmersiveWindowStatus(status: string): void {
    AppStorage.setOrCreate<string>(IMMERSIVE_WINDOW_STATUS_KEY, status);
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    if (this.mainWindowStage !== undefined && this.windowCloseGuardRegistered) {
      try {
        let mainWindow: window.Window = this.mainWindowStage.getMainWindowSync();
        mainWindow.off('windowWillClose', this.windowCloseGuardCallback);
      } catch (err) {
        hilog.warn(DOMAIN, 'testTag', 'windowWillClose guard cleanup failed: %{public}s', String(err));
      }
    }
    this.windowCloseGuardRegistered = false;
    this.mainWindowStage = undefined;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    this.reapplyImmersiveWindow('foreground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
