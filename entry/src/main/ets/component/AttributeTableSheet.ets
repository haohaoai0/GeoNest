import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '../utils/MaterialStyle';
import { getGisService, GisLoadedLayer, qgisCategoryTotal, qgisRampColor } from '../gis/GisService';
import { GisAttributeValue, GisFeatureSummary, GisFieldInfo } from '../model/GeoNestModels';

class DialogLayerChoice {
  name: string = '';
  meta: string = '';
  key: string = '';
}

class ShapefileSidecar {
  extension: string = '';
  suffixChoice: string = '';

  constructor(extension: string, suffixChoice: string) {
    this.extension = extension;
    this.suffixChoice = suffixChoice;
  }
}

@Component
export struct AttributeTableSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  activeLayerRevision: number = 0;
  onLocateFeature: (featureId: string, layerIndex: number) => void = () => {};
  @State private filterText: string = '';
  @State private sortMode: number = 0;
  @State private selectedRowId: string = '';
  @State private selectedRowLayerKey: string = '';

  onTrigger(): void {
    this.isShow = true;
  }

  private getActiveLayer(): GisLoadedLayer | undefined {
    return getGisService().getActiveLayer();
  }

  private getActiveLayerIndex(): number {
    return getGisService().getActiveLayerIndex();
  }

  private activeLayerKey(): string {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      return 'attribute:none:' + this.activeLayerRevision.toString();
    }
    return 'attribute:' + this.getActiveLayerIndex().toString() + ':' + layer.info.layerId + ':' +
      this.activeLayerRevision.toString();
  }

  private geometryTypeName(geometryType: number): string {
    if (geometryType === 1) {
      return '点';
    }
    if (geometryType === 2) {
      return '线';
    }
    if (geometryType === 3) {
      return '面';
    }
    return '未知';
  }

  private envelopeText(layer: GisLoadedLayer): string {
    return layer.info.envelope.minX.toFixed(4) + ', ' + layer.info.envelope.minY.toFixed(4) + ' - ' +
      layer.info.envelope.maxX.toFixed(4) + ', ' + layer.info.envelope.maxY.toFixed(4);
  }

  private crsText(layer: GisLoadedLayer): string {
    if (layer.info.crs.length > 0) {
      return layer.info.crs;
    }
    return '未声明坐标系';
  }

  private attrText(attr: GisAttributeValue): string {
    if (attr.isNull) {
      return '(空)';
    }
    if (attr.textValue.length > 0) {
      return attr.textValue;
    }
    return attr.numberValue.toString();
  }

  private attrByName(row: GisFeatureSummary, fieldName: string): string {
    for (let i = 0; i < row.attributesPreview.length; i++) {
      let attr = row.attributesPreview[i];
      if (attr.name === fieldName) {
        return this.attrText(attr);
      }
    }
    return '';
  }

  private rowMatchesFilter(row: GisFeatureSummary): boolean {
    if (this.filterText.length === 0) {
      return true;
    }
    let text = this.filterText.toLowerCase();
    if (row.featureId.toLowerCase().indexOf(text) >= 0) {
      return true;
    }
    for (let i = 0; i < row.attributesPreview.length; i++) {
      let attr = row.attributesPreview[i];
      if (attr.name.toLowerCase().indexOf(text) >= 0) {
        return true;
      }
      if (this.attrText(attr).toLowerCase().indexOf(text) >= 0) {
        return true;
      }
    }
    return false;
  }

  private compareRows(left: GisFeatureSummary, right: GisFeatureSummary): number {
    let leftId = Number(left.featureId);
    let rightId = Number(right.featureId);
    if (this.sortMode === 1) {
      return rightId - leftId;
    }
    if (this.sortMode === 2) {
      let layer = this.getActiveLayer();
      if (layer !== undefined && layer.info.fields.length > 0) {
        let fieldName = layer.info.fields[0].name;
        return this.attrByName(left, fieldName).localeCompare(this.attrByName(right, fieldName));
      }
    }
    return leftId - rightId;
  }

  private insertSorted(rows: GisFeatureSummary[], row: GisFeatureSummary): void {
    if (rows.length === 0) {
      rows.push(row);
      return;
    }
    for (let i = 0; i < rows.length; i++) {
      if (this.compareRows(row, rows[i]) < 0) {
        rows.splice(i, 0, row);
        return;
      }
    }
    rows.push(row);
  }

  private buildVisibleRows(layer: GisLoadedLayer): GisFeatureSummary[] {
    let rows: GisFeatureSummary[] = [];
    for (let i = 0; i < layer.features.length; i++) {
      let row = layer.features[i];
      if (this.rowMatchesFilter(row)) {
        this.insertSorted(rows, row);
      }
    }
    return rows;
  }

  private fieldStatsText(field: GisFieldInfo): string {
    let layer = this.getActiveLayer();
    if (layer === undefined) {
      return '';
    }
    let nonEmptyCount = 0;
    let numericCount = 0;
    let minValue = 0.0;
    let maxValue = 0.0;
    let hasNumber = false;
    for (let i = 0; i < layer.features.length; i++) {
      let row = layer.features[i];
      for (let j = 0; j < row.attributesPreview.length; j++) {
        let attr = row.attributesPreview[j];
        if (attr.name === field.name && !attr.isNull) {
          nonEmptyCount++;
          let value = Number(this.attrText(attr));
          if (value === value) {
            numericCount++;
            if (!hasNumber) {
              minValue = value;
              maxValue = value;
              hasNumber = true;
            } else {
              if (value < minValue) {
                minValue = value;
              }
              if (value > maxValue) {
                maxValue = value;
              }
            }
          }
        }
      }
    }
    if (hasNumber) {
      return nonEmptyCount.toString() + ' 非空 · 数值 ' + numericCount.toString() + ' · ' +
        minValue.toFixed(2) + ' - ' + maxValue.toFixed(2);
    }
    return nonEmptyCount.toString() + ' 非空';
  }

  private firstAttributes(attrs: GisAttributeValue[]): GisAttributeValue[] {
    let result: GisAttributeValue[] = [];
    let maxCount = attrs.length;
    if (maxCount > 8) {
      maxCount = 8;
    }
    for (let i = 0; i < maxCount; i++) {
      result.push(attrs[i]);
    }
    return result;
  }

  @Builder
  metricText(label: ResourceStr, value: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.gn_text_primary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  summaryPanel(layer: GisLoadedLayer) {
    Column({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.layer'))
          .fontSize(30)
          .fontColor([$r('app.color.gn_blue_800')])
          .margin({ right: 12 })
        Column() {
          Text(layer.info.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.gn_text_primary'))
          Text(this.geometryTypeName(layer.info.geometryType) + '图层 · ' + this.crsText(layer))
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }

      Row() {
        this.metricText($r('app.string.gn_features'), layer.info.featureCount.toString())
        this.metricText($r('app.string.gn_attribute_rows'), layer.features.length.toString())
        this.metricText($r('app.string.gn_details'), layer.info.fields.length.toString() + ' 字段')
      }

      Text(this.envelopeText(layer))
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  colorSwatch(colorValue: string) {
    Text('')
      .width(44)
      .height(20)
      .borderRadius(4)
      .backgroundColor(colorValue)
      .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  symbolRow(label: string, colorValue: string, detail: string) {
    Row({ space: 10 }) {
      this.colorSwatch(colorValue)
      Column() {
        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(detail)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .height(42)
  }

  private layerRendererModeName(layer: GisLoadedLayer): string {
    if (layer.style.rendererMode === 1) {
      return '分类渲染';
    }
    if (layer.style.rendererMode === 2) {
      return '分级渲染';
    }
    return '单一符号';
  }

  private layerRampTotal(layer: GisLoadedLayer): number {
    if (layer.style.rendererMode === 1) {
      return qgisCategoryTotal(layer, layer.style.rendererField);
    }
    if (layer.style.rendererMode === 2) {
      return 5;
    }
    return 1;
  }

  private layerPreviewColor(layer: GisLoadedLayer): string {
    if (layer.style.rendererMode === 1 || layer.style.rendererMode === 2) {
      return qgisRampColor(layer.style.colorRamp, 0, this.layerRampTotal(layer));
    }
    if (layer.info.geometryType === 1) {
      return layer.style.pointColor;
    }
    if (layer.info.geometryType === 2) {
      return layer.style.lineColor;
    }
    return layer.style.fillColor;
  }

  private layerPreviewLabel(layer: GisLoadedLayer): string {
    if (layer.style.rendererMode === 1 || layer.style.rendererMode === 2) {
      return 'QGIS 色带';
    }
    if (layer.info.geometryType === 1) {
      return '点符号';
    }
    if (layer.info.geometryType === 2) {
      return '线符号';
    }
    return '面填充';
  }

  private layerPreviewDetail(layer: GisLoadedLayer): string {
    if (layer.style.rendererMode === 1 || layer.style.rendererMode === 2) {
      let fieldName = layer.style.rendererField.length > 0 ? layer.style.rendererField : '未选择字段';
      return this.layerRendererModeName(layer) + ' · ' + fieldName;
    }
    if (layer.info.geometryType === 1) {
      return '半径 ' + layer.style.pointRadius.toString() + ' px';
    }
    if (layer.info.geometryType === 2) {
      return '线宽 ' + layer.style.lineWidth.toString() + ' px';
    }
    return '单一符号填充';
  }

  @Builder
  symbolPanel(layer: GisLoadedLayer) {
    Column({ space: 8 }) {
      Text($r('app.string.gn_symbology'))
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      this.symbolRow(this.layerPreviewLabel(layer), this.layerPreviewColor(layer), this.layerPreviewDetail(layer))
      if (layer.info.geometryType === 3) {
        this.symbolRow('边界线', layer.style.strokeColor, '线宽 ' + layer.style.lineWidth.toString() + ' px')
      }
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  fieldChip(field: GisFieldInfo) {
    Column() {
      Row({ space: 4 }) {
        Text(field.name)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(field.typeName)
          .fontSize(10)
          .fontColor($r('app.color.gn_text_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(this.fieldStatsText(field))
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
        .margin({ top: 3 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(42)
    .padding({ left: 8, right: 8 })
    .margin({ right: 6, bottom: 6 })
    .borderRadius(4)
    .backgroundColor($r('app.color.gn_pane'))
  }

  @Builder
  fieldPanel(layer: GisLoadedLayer) {
    Column({ space: 8 }) {
      Text('字段')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(layer.info.fields, (field: GisFieldInfo) => {
          this.fieldChip(field)
        }, (field: GisFieldInfo) => this.activeLayerKey() + ':field:' + field.name)
      }
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  attrCell(attr: GisAttributeValue) {
    Row() {
      Text(attr.name)
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .width(92)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.attrText(attr))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
  }

  @Builder
  rowItem(row: GisFeatureSummary) {
    ListItem() {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Column() {
            Text('FID ' + row.featureId)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.gn_text_primary'))
            Text(row.envelope.minX.toFixed(4) + ', ' + row.envelope.minY.toFixed(4) + ' - ' +
              row.envelope.maxX.toFixed(4) + ', ' + row.envelope.maxY.toFixed(4))
              .fontSize(12)
              .fontColor($r('app.color.gn_text_muted'))
              .margin({ top: 4 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Button($r('app.string.gn_locate_feature'), { type: ButtonType.Capsule, stateEffect: true })
            .height(28)
            .fontSize(12)
            .fontColor($r('app.color.gn_blue_800'))
            .backgroundColor($r('app.color.gn_blue_100'))
            .onClick(() => {
              this.selectedRowId = row.featureId;
              this.selectedRowLayerKey = this.activeLayerKey();
              this.onLocateFeature(row.featureId, this.getActiveLayerIndex());
            })
        }
        .width('100%')

        ForEach(this.firstAttributes(row.attributesPreview), (attr: GisAttributeValue) => {
          this.attrCell(attr)
        }, (attr: GisAttributeValue) => this.activeLayerKey() + ':attr:' + row.featureId + ':' + attr.name)
      }
      .padding({ left: 12, right: 12 })
      .borderRadius(6)
      .backgroundColor(this.selectedRowLayerKey === this.activeLayerKey() && this.selectedRowId === row.featureId ?
        $r('app.color.gn_arc_selected') : $r('app.color.gn_paper'))
    }
  }

  @Builder
  sortButton(label: ResourceStr, mode: number) {
    Text(label)
      .height(26)
      .padding({ left: 10, right: 10 })
      .fontSize(12)
      .fontWeight(this.sortMode === mode ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.sortMode === mode ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(this.sortMode === mode ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(4)
      .onClick(() => {
        this.sortMode = mode;
      })
  }

  @Builder
  tableQueryBar(layer: GisLoadedLayer) {
    Column({ space: 8 }) {
      Search({ placeholder: $r('app.string.gn_attribute_filter_placeholder') })
        .height(32)
        .backgroundColor($r('app.color.gn_pane'))
        .onChange((value: string) => {
          this.filterText = value;
        })
      Row({ space: 8 }) {
        Text($r('app.string.gn_attribute_sort_label'))
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
        this.sortButton($r('app.string.gn_sort_fid_asc'), 0)
        this.sortButton($r('app.string.gn_sort_fid_desc'), 1)
        if (layer.info.fields.length > 0) {
          this.sortButton($r('app.string.gn_sort_first_field'), 2)
        }
        Blank()
        Text(this.buildVisibleRows(layer).length.toString() + ' / ' + layer.features.length.toString())
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
      }
      .height(28)
    }
    .padding(12)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              Blank().height(80).width('100%')
              Text(this.activeLayerKey())
                .width(0)
                .height(0)
                .fontSize(0)
                .opacity(0)
              if (this.getActiveLayer() === undefined) {
                Column({ space: 8 }) {
                  Text('当前没有已加载图层')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.gn_text_primary'))
                  Text('先添加 Shapefile，或选择图层后再打开属性表。')
                    .fontSize(12)
                    .fontColor($r('app.color.gn_text_muted'))
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
              } else {
                Column({ space: 12 }) {
                  this.summaryPanel(this.getActiveLayer() as GisLoadedLayer)
                  this.fieldPanel(this.getActiveLayer() as GisLoadedLayer)
                  this.tableQueryBar(this.getActiveLayer() as GisLoadedLayer)
                }
                .padding(14)
              }
            }.width('100%')
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .layoutWeight(1)

          if (this.getActiveLayer() !== undefined) {
            Column() {
              Text($r('app.string.gn_attribute_rows'))
                .width('100%')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.gn_text_primary'))
                .padding({ left: 14, right: 14, top: 10, bottom: 6 })
              List({ space: 8 }) {
                ForEach(this.buildVisibleRows(this.getActiveLayer() as GisLoadedLayer), (row: GisFeatureSummary) => {
                  this.rowItem(row)
                }, (row: GisFeatureSummary) => this.activeLayerKey() + ':row:' + row.featureId)
              }
              .layoutWeight(1)
              .scrollBar(BarState.Auto)
              .padding({ left: 14, right: 14 })
            }
            .layoutWeight(1)
          }
        }
        .width('100%').height('100%')
      }
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar({
        style: MaterialStyle.isHigh() && this.materialEnabled ? {
          scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          }
        } : undefined,
        content: {
          title: { mainTitle: $r('app.string.gn_workbench_attribute_table') },
          menu: {
            value: [{
              content: {
                label: 'modal_cancel', isEnabled: true,
                type: IconStyleMode.SMALL,
                action: () => { this.isShow = false; }
              }
            }]
          }
        }
      })
    }
    .width('100%').height('100%')
  }

  build() {
    Row().width(0).height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        detents: [SheetSize.LARGE],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Thin,
        systemMaterial: MaterialStyle.nativeMaterial(this.materialEnabled),
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}