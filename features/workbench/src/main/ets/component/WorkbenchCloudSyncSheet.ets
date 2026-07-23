import { MaterialStyle } from '@geonest/common';

@Component
export struct WorkbenchCloudSyncSheet {
  @Prop statusText: string = '';
  @Prop projectText: string = '';
  @Prop timeText: string = '';
  @Prop actionText: string = '';
  @Prop logs: string[] = [];
  @Prop paneRadius: number = 8;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  onClose: () => void = (): void => {};
  onManage: () => void = (): void => {};
  onPush: () => void = (): void => {};
  onPull: () => void = (): void => {};

  @Builder
  infoRow(label: ResourceStr, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width(74)
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text($r('app.string.gn_cloud_sheet_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Text($r('app.string.gn_cloud_sheet_desc'))
            .fontSize(13)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('关闭', { type: ButtonType.Capsule, stateEffect: true })
          .fontSize(13)
          .fontColor($r('app.color.gn_text_primary'))
          .backgroundColor($r('app.color.gn_pane_alt'))
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 10 }) {
        this.infoRow($r('app.string.gn_cloud_status_label'), this.statusText)
        this.infoRow($r('app.string.gn_cloud_project_label'), this.projectText)
        this.infoRow($r('app.string.gn_cloud_time_label'), this.timeText)
        this.infoRow($r('app.string.gn_cloud_action_label'), this.actionText)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      .borderRadius(this.paneRadius)

      Row({ space: 8 }) {
        Button($r('app.string.gn_cmd_cloud_manage'), { type: ButtonType.Capsule, stateEffect: true })
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.gn_text_primary'))
          .backgroundColor($r('app.color.gn_pane_alt'))
          .onClick(() => {
            this.onManage();
          })
        Button($r('app.string.gn_cmd_cloud_push'), { type: ButtonType.Capsule, stateEffect: true })
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.gn_blue_800'))
          .backgroundColor($r('app.color.gn_blue_100'))
          .onClick(() => {
            this.onPush();
          })
        Button($r('app.string.gn_cmd_cloud_pull'), { type: ButtonType.Capsule, stateEffect: true })
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.gn_green_700'))
          .backgroundColor($r('app.color.gn_pane_alt'))
          .onClick(() => {
            this.onPull();
          })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text($r('app.string.gn_cloud_logs_label'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Scroll() {
          Column({ space: 8 }) {
            if (this.logs.length === 0) {
              Text('暂无同步日志')
                .fontSize(12)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
            } else {
              ForEach(this.logs, (item: string) => {
                Text(item)
                  .fontSize(12)
                  .fontColor($r('app.color.gn_text_primary'))
                  .width('100%')
              }, (item: string) => item)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(180)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
      .borderRadius(this.paneRadius)
    }
    .width('100%')
    .padding(24)
    .backgroundBlurStyle(MaterialStyle.panelBlurStyle())
    .backgroundColor(this.surfaceColor)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
    .borderRadius(this.paneRadius)
  }
}
