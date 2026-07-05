import { GisAttributeValue } from '../model/GeoNestModels';

// ---------------------------------------------------------------------------
// GisFeatureInfoPanel: displays selected feature's attributes
// ---------------------------------------------------------------------------
@Component
export struct GisFeatureInfoPanel {
  @Prop featureId: string = '';
  @Prop featureKey: string = '';
  @Prop layerName: string = '';
  @Prop attributes: GisAttributeValue[] = [];
  @Prop geometryType: number = 0;
  @Prop featureCount: number = 0;
  onPanelClose: () => void = () => {};

  private geometryTypeName(): string {
    if (this.geometryType === 1) return '点';
    if (this.geometryType === 2) return '线';
    if (this.geometryType === 3) return '面';
    return '未知';
  }

  private attributeText(attr: GisAttributeValue): string {
    if (attr.isNull) {
      return '(空)';
    }
    if (attr.textValue.length > 0) {
      return attr.textValue;
    }
    let typeName = attr.typeName.toLowerCase();
    if (typeName.indexOf('bool') >= 0) {
      return attr.boolValue ? 'true' : 'false';
    }
    if (typeName.indexOf('int') >= 0 || typeName.indexOf('real') >= 0 || typeName.indexOf('double') >= 0 ||
      typeName.indexOf('float') >= 0 || typeName.indexOf('number') >= 0 || typeName.indexOf('numeric') >= 0) {
      return attr.numberValue.toString();
    }
    return '';
  }

  @Builder
  attributeRow(attr: GisAttributeValue) {
    Row() {
      Text(attr.name)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width(90)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.attributeText(attr))
        .fontSize(13)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(32)
    .padding({ left: 10, right: 10 })
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }

  build() {
    Column() {
      Text(this.featureKey)
        .width(0)
        .height(0)
        .fontSize(0)
        .opacity(0)
      // Header
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.hand_tap'))
          .fontSize(16)
          .fontColor([$r('app.color.gn_blue_800')])
        Text(this.featureId.length > 0 ? ('要素 #' + this.featureId) : '未选中')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.layerName)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(14)
            .fontColor([$r('app.color.gn_text_primary')])
        }
        .width(28)
        .height(28)
        .padding(0)
        .borderRadius(6)
        .backgroundColor($r('app.color.gn_pane'))
        .border({ width: 1, color: $r('app.color.gn_line') })
          .onClick(() => {
            this.onPanelClose();
          })
      }
      .height(36)
      .padding({ left: 10, right: 8 })
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })

      // Feature metadata
      if (this.featureId.length > 0) {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text(this.geometryTypeName())
              .fontSize(11)
              .fontColor($r('app.color.gn_text_muted'))
            Text($r('app.string.gn_details'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.gn_text_primary'))
          }
          .alignItems(HorizontalAlign.Center)
          .layoutWeight(1)
        }
        .height(40)
        .padding({ left: 10, right: 10 })
        .backgroundColor($r('app.color.gn_pane'))
        .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })

        // Attributes list
        Scroll() {
          Column() {
            ForEach(this.attributes, (attr: GisAttributeValue) => {
              this.attributeRow(attr);
            }, (attr: GisAttributeValue) => this.featureKey + ':' + attr.name)
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      } else {
        Column() {
          Text('点击地图上的要素以查看属性')
            .fontSize(13)
            .fontColor($r('app.color.gn_text_muted'))
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width(318)
    .height('100%')
    .backgroundColor($r('app.color.gn_pane'))
    .borderRadius(10)
    .clip(true)
    .border({ width: 1, color: $r('app.color.gn_line_strong') })
  }
}

