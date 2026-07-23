let geoNestCardStorage: LocalStorage = new LocalStorage();

@Entry(geoNestCardStorage)
@Component
struct GeoNestCard {
  @LocalStorageProp('projectName') projectName: string = '未命名工程';
  @LocalStorageProp('projectFileName') projectFileName: string = '未保存工程';
  @LocalStorageProp('layerSummary') layerSummary: string = '暂无图层';
  @LocalStorageProp('cloudStatus') cloudStatus: string = '云空间同步未初始化';
  @LocalStorageProp('processingStatus') processingStatus: string = '暂无处理任务';
  @LocalStorageProp('actionHint') actionHint: string = '打开工程 · 添加数据 · 继续上次工作';
  @LocalStorageProp('thumbnailUri') thumbnailUri: string = '';
  @LocalStorageProp('updatedText') updatedText: string = '刚刚更新';

  private readonly actionType: string = 'router';
  private readonly abilityName: string = 'EntryAbility';
  private readonly actionMessage: string = 'continue';

  build() {
    Column({ space: 7 }) {
      Row({ space: 6 }) {
        Text('GeoNest GIS')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1220')
          .layoutWeight(1)
        Text(this.updatedText)
          .fontSize(10)
          .fontColor('#64748B')
      }
      .width('100%')

      this.mapThumbnail()

      Column({ space: 3 }) {
        Text(this.projectName)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.projectFileName)
          .fontSize(10)
          .fontColor('#64748B')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 6 }) {
        this.statusBadge('云', this.cloudStatus)
        this.statusBadge('处理', this.processingStatus)
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.actionHint)
        .width('100%')
        .height(24)
        .fontSize(11)
        .fontColor('#075985')
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .backgroundColor('#E0F2FE')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#F8FAFC')
    .borderRadius(18)
    .onClick(() => {
      postCardAction(this, {
        action: this.actionType,
        abilityName: this.abilityName,
        params: {
          geonestFormAction: this.actionMessage
        }
      });
    })
  }

  @Builder
  mapThumbnail() {
    Stack({ alignContent: Alignment.BottomStart }) {
      if (this.thumbnailUri.length > 0) {
        Image(this.thumbnailUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column({ space: 4 }) {
          Text('地图缩略图')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#334155')
          Text('打开工程后自动生成')
            .fontSize(10)
            .fontColor('#64748B')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#E2E8F0')
      }

      Text(this.layerSummary)
        .fontSize(10)
        .fontColor('#F8FAFC')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor('#660F172A')
        .borderRadius(9)
        .margin({ left: 8, bottom: 6, right: 8 })
    }
    .width('100%')
    .height(58)
    .borderRadius(12)
    .clip(true)
    .backgroundColor('#E2E8F0')
  }

  @Builder
  statusBadge(label: string, value: string) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#075985')
      Text(value)
        .fontSize(10)
        .fontColor('#64748B')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(22)
    .layoutWeight(1)
    .padding({ left: 7, right: 7 })
    .borderRadius(11)
    .backgroundColor('#E0F2FE')
  }
}
