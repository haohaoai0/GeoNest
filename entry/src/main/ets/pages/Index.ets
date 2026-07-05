import { GeoNestWorkbenchView } from '../view/GeoNestWorkbenchView';
import { LaunchSplash } from '../component/LaunchSplash';
import {
  APP_STARTUP_ANIMATION_KEY,
  DEFAULT_STARTUP_ANIMATION_ENABLED
} from '../model/AppPreferences';

@Entry
@Component
struct Index {
  @State private showLaunchSplash: boolean = true;
  @StorageLink(APP_STARTUP_ANIMATION_KEY) private startupAnimationEnabled: boolean =
    DEFAULT_STARTUP_ANIMATION_ENABLED;

  aboutToAppear(): void {
    this.showLaunchSplash = this.startupAnimationEnabled;
  }

  build() {
    Stack() {
      GeoNestWorkbenchView()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.gn_launch_background'))

      if (this.showLaunchSplash) {
        LaunchSplash({
          onFinish: () => {
            this.showLaunchSplash = false;
          }
        })
          .width('100%')
          .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.gn_launch_background'))
  }
}
