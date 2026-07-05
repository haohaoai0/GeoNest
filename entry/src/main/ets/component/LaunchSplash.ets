const LAUNCH_ENTER_DELAY: number = 80;
const LAUNCH_ORBIT_DELAY: number = 460;
const LAUNCH_TEXT_DELAY: number = 880;
const LAUNCH_MAX_DURATION: number = 2400;
const LAUNCH_EXIT_DURATION: number = 360;

@Component
export struct LaunchSplash {
  onFinish: () => void = () => {};

  @State private splashOpacity: number = 1.0;
  @State private fallbackOpacity: number = 0.0;
  @State private fallbackScale: number = 0.9;
  @State private fallbackTranslateY: number = 18.0;
  @State private ringOpacity: number = 0.0;
  @State private ringScale: number = 0.78;
  @State private ringRotation: number = -20.0;
  @State private textOpacity: number = 0.0;
  @State private textTranslateY: number = 10.0;
  @State private pulseOpacity: number = 0.0;
  @State private pulseScale: number = 0.88;

  private started: boolean = false;
  private closing: boolean = false;
  private enterTimer: number = -1;
  private orbitTimer: number = -1;
  private textTimer: number = -1;
  private exitTimer: number = -1;
  private finishTimer: number = -1;

  aboutToDisappear(): void {
    this.clearAllTimers();
  }

  private startSplash(): void {
    if (this.started) {
      return;
    }
    this.started = true;

    this.enterTimer = setTimeout(() => {
      this.fallbackOpacity = 1.0;
      this.fallbackScale = 1.0;
      this.fallbackTranslateY = 0.0;
      this.ringOpacity = 0.76;
      this.ringScale = 1.0;
      this.pulseOpacity = 0.46;
    }, LAUNCH_ENTER_DELAY);

    this.orbitTimer = setTimeout(() => {
      this.ringRotation = 340.0;
      this.pulseScale = 1.16;
      this.pulseOpacity = 0.0;
    }, LAUNCH_ORBIT_DELAY);

    this.textTimer = setTimeout(() => {
      this.textOpacity = 1.0;
      this.textTranslateY = 0.0;
    }, LAUNCH_TEXT_DELAY);

    this.scheduleExit(LAUNCH_MAX_DURATION);
  }

  private scheduleExit(delay: number): void {
    if (this.exitTimer >= 0) {
      clearTimeout(this.exitTimer);
      this.exitTimer = -1;
    }
    this.exitTimer = setTimeout(() => {
      this.closeSplash();
    }, delay);
  }

  private closeSplash(): void {
    if (this.closing) {
      return;
    }
    this.closing = true;
    this.clearPlaybackTimers();

    this.splashOpacity = 0.0;
    this.fallbackScale = 1.04;
    this.textTranslateY = -8.0;

    this.finishTimer = setTimeout(() => {
      this.onFinish();
    }, LAUNCH_EXIT_DURATION + 40);
  }

  private clearPlaybackTimers(): void {
    if (this.enterTimer >= 0) {
      clearTimeout(this.enterTimer);
      this.enterTimer = -1;
    }
    if (this.orbitTimer >= 0) {
      clearTimeout(this.orbitTimer);
      this.orbitTimer = -1;
    }
    if (this.textTimer >= 0) {
      clearTimeout(this.textTimer);
      this.textTimer = -1;
    }
    if (this.exitTimer >= 0) {
      clearTimeout(this.exitTimer);
      this.exitTimer = -1;
    }
  }

  private clearAllTimers(): void {
    this.clearPlaybackTimers();
    if (this.finishTimer >= 0) {
      clearTimeout(this.finishTimer);
      this.finishTimer = -1;
    }
  }

  @Builder
  private orbitLayer() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(372)
        .height(372)
        .borderRadius(186)
        .border({ width: 1, color: $r('app.color.gn_launch_ring_blue') })
      Column()
        .width(298)
        .height(298)
        .borderRadius(149)
        .border({ width: 1, color: $r('app.color.gn_launch_ring_green') })
      Row()
        .width(260)
        .height(2)
        .borderRadius(1)
        .backgroundColor($r('app.color.gn_launch_ring_blue'))
      Row()
        .width(2)
        .height(260)
        .borderRadius(1)
        .backgroundColor($r('app.color.gn_launch_ring_green'))
    }
    .width(392)
    .height(392)
    .scale({ x: this.ringScale, y: this.ringScale })
    .rotate({ angle: this.ringRotation })
    .opacity(this.ringOpacity)
    .animation({ duration: 1700, curve: Curve.EaseInOut })
  }

  @Builder
  private fallbackLogoLayer() {
    Column() {
      Image($r('app.media.geonest_launch_mark'))
        .width(312)
        .height(292)
        .objectFit(ImageFit.Contain)
      Image($r('app.media.geonest_launch_wordmark'))
        .width(322)
        .height(69)
        .objectFit(ImageFit.Contain)
        .margin({ top: 8 })
      Image($r('app.media.geonest_launch_gis'))
        .width(260)
        .height(35)
        .objectFit(ImageFit.Contain)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
    .scale({ x: this.fallbackScale, y: this.fallbackScale })
    .translate({ y: this.fallbackTranslateY })
    .opacity(this.fallbackOpacity)
    .animation({ duration: 720, curve: Curve.EaseOut })
  }

  @Builder
  private mediaLayer() {
    Stack({ alignContent: Alignment.Center }) {
      this.fallbackLogoLayer()
    }
    .width(420)
    .height(420)
    .backgroundColor($r('app.color.gn_launch_background'))
    .renderGroup(true)
  }

  @Builder
  private statusLayer() {
    Column() {
      Text($r('app.string.gn_launch_status'))
        .fontSize(13)
        .fontColor($r('app.color.gn_launch_muted'))
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 8 }) {
        Column()
          .width(28)
          .height(3)
          .borderRadius(2)
          .backgroundColor($r('app.color.gn_launch_progress'))
        Column()
          .width(28)
          .height(3)
          .borderRadius(2)
          .backgroundColor($r('app.color.gn_launch_track'))
        Column()
          .width(28)
          .height(3)
          .borderRadius(2)
          .backgroundColor($r('app.color.gn_launch_track'))
      }
      .margin({ top: 14 })
    }
    .opacity(this.textOpacity)
    .translate({ y: this.textTranslateY })
    .animation({ duration: 520, curve: Curve.EaseOut })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.gn_launch_background'))

      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(430)
            .height(430)
            .borderRadius(215)
            .backgroundColor($r('app.color.gn_launch_pulse'))
            .scale({ x: this.pulseScale, y: this.pulseScale })
            .opacity(this.pulseOpacity)
            .animation({ duration: 1700, curve: Curve.EaseInOut })
          this.orbitLayer()
          this.mediaLayer()
        }
        .width(460)
        .height(460)
        .renderGroup(true)

        Column() {
          this.statusLayer()
        }
        .margin({ top: 18 })
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width('100%')
      .height('100%')
      .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .height('100%')
    .opacity(this.splashOpacity)
    .animation({ duration: LAUNCH_EXIT_DURATION, curve: Curve.EaseIn })
    .onAppear(() => {
      this.startSplash();
    })
  }
}
