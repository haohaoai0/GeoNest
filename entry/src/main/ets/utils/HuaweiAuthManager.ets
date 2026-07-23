import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { commonEventManager, emitter } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';

const TAG = 'HuaweiAuthManager';
const DOMAIN = 0x0000;
const PREF_NAME = 'huawei_auth';
const KEY_USER_LOGIN = 'user_login';
const KEY_USER_ACCOUNT = 'user_account';

export interface HuaweiAuthResult {
  unionID: string;
  openID: string;
  nickName: string;
  avatarUri: string;
}

export const HUAWEI_LOGIN_EVENT = 'huawei_login_event';
export const HUAWEI_LOGOUT_EVENT = 'huawei_logout_event';

export class HuaweiAuthManager {
  private static instance: HuaweiAuthManager;
  private uiAbilityContext: common.UIAbilityContext | undefined = undefined;
  private userAccount: HuaweiAuthResult | null = null;
  private isUserLogin: boolean = false;
  private loginCallbacks: ((userAccount: HuaweiAuthResult) => void)[] = [];
  private logoutCallbacks: (() => void)[] = [];
  private preferencesStore: preferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): HuaweiAuthManager {
    if (!HuaweiAuthManager.instance) {
      HuaweiAuthManager.instance = new HuaweiAuthManager();
    }
    return HuaweiAuthManager.instance;
  }

  public setContext(context: common.UIAbilityContext): void {
    this.uiAbilityContext = context;
  }

  public isLogin(): boolean {
    return this.isUserLogin;
  }

  public getUserInfo(): HuaweiAuthResult | null {
    return this.userAccount;
  }

  public addLoginListener(callback: (userAccount: HuaweiAuthResult) => void): void {
    this.loginCallbacks.push(callback);
  }

  public addLogoutListener(callback: () => void): void {
    this.logoutCallbacks.push(callback);
  }

  public async init(): Promise<void> {
    if (this.uiAbilityContext === undefined) {
      return;
    }

    try {
      await this.ensurePreferencesStore();
      if (this.preferencesStore === null) {
        return;
      }
      this.isUserLogin = await this.preferencesStore.get(KEY_USER_LOGIN, false) as boolean;
      const accountJson: string = await this.preferencesStore.get(KEY_USER_ACCOUNT, '') as string;

      if (this.isUserLogin && accountJson.length > 0) {
        try {
          this.userAccount = JSON.parse(accountJson) as HuaweiAuthResult;
          this.syncToAppStorage();
        } catch (e) {
          this.userAccount = null;
          this.isUserLogin = false;
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to init preferences: ' + (e as BusinessError).code);
    }

    this.subscribeAccountLoginState();

    let loginStateRequest: authentication.StateRequest | null = this.createLoginStateRequest();
    if (loginStateRequest === null) {
      return;
    }

    try {
      const result: authentication.StateResult =
        await new authentication.HuaweiIDProvider().getHuaweiIDState(loginStateRequest);

      if (result.state !== authentication.State.AUTHORIZED) {
        if (this.isUserLogin) {
          this.isUserLogin = false;
          this.userAccount = null;
          await this.saveToStorage();
          this.syncToAppStorage();
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Check login state failed: ' + (error as BusinessError).code);
    }
  }

  private createLoginStateRequest(): authentication.StateRequest | null {
    if (this.userAccount === null) {
      return null;
    }
    if (this.userAccount.unionID.length > 0) {
      return {
        idType: authentication.IdType.UNION_ID,
        idValue: this.userAccount.unionID,
      };
    }
    if (this.userAccount.openID.length > 0) {
      return {
        idType: authentication.IdType.OPEN_ID,
        idValue: this.userAccount.openID,
      };
    }
    return null;
  }

  private subscribeAccountLoginState(): void {
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [
        commonEventManager.Support.COMMON_EVENT_DISTRIBUTED_ACCOUNT_LOGIN,
        commonEventManager.Support.COMMON_EVENT_DISTRIBUTED_ACCOUNT_LOGOUT,
      ],
    };

    commonEventManager.createSubscriber(subscribeInfo)
      .then((subscriber: commonEventManager.CommonEventSubscriber) => {
        commonEventManager.subscribe(subscriber,
          (error: BusinessError, data: commonEventManager.CommonEventData) => {
            if (!error && data.event === commonEventManager.Support.COMMON_EVENT_DISTRIBUTED_ACCOUNT_LOGOUT) {
              this.isUserLogin = false;
              this.userAccount = null;
              this.notifyLogout();
              emitter.emit(HUAWEI_LOGOUT_EVENT);
            }
          });
      })
      .catch(() => {});
  }

  public async login(uiContext?: UIContext): Promise<HuaweiAuthResult> {
    if (this.uiAbilityContext === undefined) {
      throw new Error('Context not set');
    }

    const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    // Keep the request aligned with the Huawei Account Kit sample used by this
    // project.  `serviceauthcode` is required when the backend needs a
    // one-time authorization code, while `profile` requests the account
    // profile fields returned below.
    authRequest.scopes = ['profile'];
    authRequest.permissions = ['serviceauthcode'];
    authRequest.forceAuthorization = true;
    authRequest.state = util.generateRandomUUID();
    authRequest.idTokenSignAlgorithm = authentication.IdTokenSignAlgorithm.PS256;

    const context = uiContext !== undefined ? uiContext.getHostContext() : this.uiAbilityContext;
    const controller = new authentication.AuthenticationController(context);

    try {
      const response = await controller.executeRequest(authRequest) as authentication.AuthorizationWithHuaweiIDResponse;

      if (response.state !== undefined && authRequest.state !== response.state) {
        throw new Error('State mismatch');
      }

      const data = response.data;
      if (data === undefined) {
        throw new Error('未获取到华为账号信息');
      }

      const unionID: string = data.unionID ?? '';
      const openID: string = data.openID ?? '';

      if (unionID === '' && openID === '') {
        throw new Error('未获取到账号标识');
      }

      let nickName: string = '华为用户';
      let avatarUri: string = '';

      if (data.nickName !== undefined && data.nickName !== '') {
        nickName = data.nickName;
      }

      if (data.avatarUri !== undefined && data.avatarUri !== '') {
        avatarUri = data.avatarUri;
      }

      this.userAccount = { unionID, openID, nickName, avatarUri };
      this.isUserLogin = true;

      await this.saveToStorage();
      this.syncToAppStorage();
      this.notifyLogin(this.userAccount);
      emitter.emit(HUAWEI_LOGIN_EVENT);

      promptAction.showToast({ message: nickName + '，欢迎回来' });

      return this.userAccount;
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Login failed: ' + err.code);
      this.handleLoginError(err);
      throw new Error('Login failed: ' + err.code);
    }
  }

  public async logout(): Promise<void> {
    const wasUserLogin: boolean = this.isUserLogin;
    let authorizationRevoked: boolean = false;

    if (wasUserLogin && this.uiAbilityContext !== undefined) {
      const controller = new authentication.AuthenticationController(this.uiAbilityContext);
      const cancelRequest = new authentication.HuaweiIDProvider().createCancelAuthorizationRequest();
      try {
        await controller.executeRequest(cancelRequest);
        authorizationRevoked = true;
      } catch (error) {
        const err: BusinessError = error as BusinessError;
        hilog.error(DOMAIN, TAG, 'Logout failed: ' + err.code);
      }
    }

    await this.clearLoginState();

    if (!wasUserLogin) {
      promptAction.showToast({ message: '当前未登录华为账号' });
    } else if (authorizationRevoked) {
      promptAction.showToast({ message: '已退出华为账号' });
    } else {
      promptAction.showToast({ message: '已退出本地登录，华为授权撤销失败，请检查网络后重试' });
    }
  }

  private notifyLogin(userAccount: HuaweiAuthResult): void {
    this.loginCallbacks.forEach((cb) => cb(userAccount));
  }

  private notifyLogout(): void {
    this.logoutCallbacks.forEach((cb) => cb());
  }

  private async clearLoginState(): Promise<void> {
    this.isUserLogin = false;
    this.userAccount = null;
    await this.saveToStorage();
    this.syncToAppStorage();
    this.notifyLogout();
    emitter.emit(HUAWEI_LOGOUT_EVENT);
  }

  private async ensurePreferencesStore(): Promise<void> {
    if (this.preferencesStore !== null || this.uiAbilityContext === undefined) {
      return;
    }
    this.preferencesStore = await preferences.getPreferences(this.uiAbilityContext, PREF_NAME);
  }

  private async saveToStorage(): Promise<void> {
    await this.ensurePreferencesStore();
    if (this.preferencesStore === null) {
      return;
    }
    try {
      await this.preferencesStore.put(KEY_USER_LOGIN, this.isUserLogin);
      await this.preferencesStore.put(KEY_USER_ACCOUNT,
        this.userAccount !== null ? JSON.stringify(this.userAccount) : '');
      await this.preferencesStore.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to save: ' + (e as BusinessError).code);
    }
  }

  private syncToAppStorage(): void {
    AppStorage.setOrCreate<boolean>('userLoggedIn', this.isUserLogin);
    if (this.userAccount !== null) {
      AppStorage.setOrCreate<string>('userNickName', this.userAccount.nickName);
      AppStorage.setOrCreate<string>('userAvatarUri', this.userAccount.avatarUri);
    } else {
      AppStorage.setOrCreate<string>('userNickName', '');
      AppStorage.setOrCreate<string>('userAvatarUri', '');
    }
  }

  private handleLoginError(error: BusinessError): void {
    if (error.code === 1001502001) {
      promptAction.showToast({ message: '请先在系统设置中登录华为账号' });
    } else if (error.code === 1001502003) {
      // Account Kit rejects the request before showing the consent sheet when
      // the HAP certificate/profile is not registered for this client ID.
      promptAction.showToast({ message: '华为账号配置无效，请检查签名证书和 AGC Profile' });
    } else if (error.code === 1001502005) {
      promptAction.showToast({ message: '网络异常，请检查网络连接' });
    } else if (error.code === 1001502002 || error.code === 1001502012) {
      // user cancelled
    } else {
      promptAction.showToast({ message: '登录失败，请稍后重试' });
    }
  }
}
