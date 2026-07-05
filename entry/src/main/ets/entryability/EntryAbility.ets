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
import { GestureShareModel } from '../gis/GestureShareModel';
import { initPreferences, APP_THEME_MODE_KEY, THEME_MODE_DARK, THEME_MODE_LIGHT } from '../model/AppPreferences';

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

export default class EntryAbility extends UIAbility {
  private mainWindowStage: window.WindowStage | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initPreferences(this.context);
    this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_PENDING_STATUS);
    this.captureExternalFileUri(want);
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
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.mainWindowStage = windowStage;
    this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_APPLYING_STATUS);

    this.applyImmersiveWindow(windowStage);

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      this.applyImmersiveWindow(windowStage);
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
    this.captureExternalFileUri(want);
    this.reapplyImmersiveWindow('new want');
  }

  private captureExternalFileUri(want: Want): void {
    let uri = want.uri;
    if (uri !== undefined && uri.length > 0) {
      AppStorage.setOrCreate<string>(EXTERNAL_FILE_URI_KEY, uri);
      hilog.info(DOMAIN, 'testTag', 'Captured external file uri.');
    } else {
      AppStorage.setOrCreate<string>(EXTERNAL_FILE_URI_KEY, '');
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
      this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_READY_STATUS);
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Window immersive mode applied.');
    } catch (err) {
      this.setImmersiveWindowStatus(IMMERSIVE_WINDOW_FAILED_STATUS);
      hilog.error(DOMAIN, 'testTag', 'Failed to get main window. Cause: %{public}s', JSON.stringify(err));
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
