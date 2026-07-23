import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { MaterialStyle } from '@geonest/common';
import { getGisService, GisLoadedLayer } from '../gis/GisService';
import { GisAttributeValue, GisFeatureSummary, GisFieldInfo, GisOperationResult } from '../model/GeoNestModels';
import { common } from '@kit.AbilityKit';
import { SnappingConfiguration } from '../model/TopologyModels';
import { TopologyRuleStore } from '../utils/TopologyRuleStore';
import {
  MAP_TOOL_EDIT_ADD_LINE,
  MAP_TOOL_EDIT_ADD_POINT,
  MAP_TOOL_EDIT_ADD_POLYGON,
  MAP_TOOL_EDIT_DELETE_NODE,
  MAP_TOOL_EDIT_MOVE_NODE,
  MAP_TOOL_SELECT_BOX,
  MAP_TOOL_SELECT_LASSO,
  MAP_TOOL_SELECT_POLYGON,
  MAP_TOOL_EDIT_CUT_SKETCH,
  MAP_TOOL_EDIT_TRACE,
  MAP_TOOL_EDIT_PARALLEL,
  MAP_TOOL_EDIT_PERPENDICULAR,
  MAP_TOOL_EDIT_ORTHOGONAL
} from '@geonest/common';

export const VECTOR_EDIT_COMMAND_COPY: number = 1;
export const VECTOR_EDIT_COMMAND_UNDO: number = 2;
export const VECTOR_EDIT_COMMAND_REDO: number = 3;
export const VECTOR_EDIT_COMMAND_CUT: number = 4;
export const VECTOR_EDIT_COMMAND_MERGE: number = 5;
export const VECTOR_EDIT_COMMAND_SNAP: number = 6;
export const VECTOR_EDIT_COMMAND_DELETE_FEATURE: number = 7;
export const VECTOR_EDIT_COMMAND_BEGIN_SESSION: number = 8;
export const VECTOR_EDIT_COMMAND_COMMIT_SESSION: number = 9;
export const VECTOR_EDIT_COMMAND_ROLLBACK_SESSION: number = 10;

@Component
export struct VectorEditSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onEditToolSelected: (toolMode: number) => void = () => {};
  onEditCommand: (command: number) => void = () => {};
  @State private snapEnabled: boolean = true;
  @State private snapTolerance: string = '8';
  @State private snapVertexPriority: number = 1;
  @State private snapSegmentPriority: number = 2;
  @State private snapEndpointPriority: number = 0;
  @State private snapCrossLayer: boolean = true;
  @State private snapSpatialIndex: boolean = true;
  @State private uiRevision: number = 0;

  onTrigger(): void {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let config: SnappingConfiguration = new TopologyRuleStore(context).loadSnappingConfiguration();
    this.snapEnabled = config.enabled;
    this.snapTolerance = config.pixelTolerance.toString();
    this.snapVertexPriority = config.vertexPriority;
    this.snapSegmentPriority = config.segmentPriority;
    this.snapEndpointPriority = config.endpointPriority;
    this.snapCrossLayer = config.crossLayer;
    this.snapSpatialIndex = config.spatialIndexEnabled;
    this.isShow = true;
  }

  private saveSnappingConfiguration(): void {
    let config: SnappingConfiguration = new SnappingConfiguration();
    let pixelTolerance: number = Number(this.snapTolerance);
    config.enabled = this.snapEnabled;
    config.pixelTolerance = pixelTolerance === pixelTolerance && pixelTolerance > 0 ? pixelTolerance : 8;
    config.vertexPriority = this.snapVertexPriority;
    config.segmentPriority = this.snapSegmentPriority;
    config.endpointPriority = this.snapEndpointPriority;
    config.crossLayer = this.snapCrossLayer;
    config.spatialIndexEnabled = this.snapSpatialIndex;
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    new TopologyRuleStore(context).saveSnappingConfiguration(config);
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private activeLayerName(): string {
    let layer = getGisService().getActiveLayer();
    if (layer === undefined) {
      return '当前没有活动图层';
    }
    return layer.info.name;
  }

  @Builder
  toolButton(label: string, icon: Resource, toolMode: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(22)
          .fontColor([$r('app.color.gn_blue_800')])
        Text(label)
          .fontSize(12)
          .fontColor($r('app.color.gn_text_primary'))
      }
      .alignItems(HorizontalAlign.Center)
    }
    .height(66)
    .layoutWeight(1)
    .backgroundColor($r('app.color.gn_pane'))
    .borderRadius(6)
    .onClick(() => {
      this.onEditToolSelected(toolMode);
      this.isShow = false;
    })
  }

  @Builder
  commandButton(label: ResourceStr, command: number) {
    Button(label, { type: ButtonType.Capsule, stateEffect: true })
      .height(30)
      .fontSize(12)
      .fontColor($r('app.color.gn_blue_800'))
      .backgroundColor($r('app.color.gn_blue_100'))
      .onClick(() => {
        this.onEditCommand(command);
      })
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            Blank().height(80).width('100%')
            Text(this.uiRevision.toString())
              .width(0)
              .height(0)
              .fontSize(0)
              .opacity(0)
            Column({ space: 4 }) {
              Text(this.activeLayerName())
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.gn_text_primary'))
                .width('100%')
              Text($r('app.string.gn_edit_session_description'))
                .fontSize(12)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
            }
            .padding(14)
            .borderRadius(6)
            .backgroundColor($r('app.color.gn_paper'))
            .border({ width: 1, color: $r('app.color.gn_line') })

            Row({ space: 8 }) {
              this.commandButton($r('app.string.gn_edit_session_begin'), VECTOR_EDIT_COMMAND_BEGIN_SESSION)
              this.commandButton($r('app.string.gn_edit_session_commit'), VECTOR_EDIT_COMMAND_COMMIT_SESSION)
              this.commandButton($r('app.string.gn_edit_session_rollback'), VECTOR_EDIT_COMMAND_ROLLBACK_SESSION)
            }

            Row({ space: 8 }) {
              this.toolButton('新增点', $r('sys.symbol.location_up'), MAP_TOOL_EDIT_ADD_POINT)
              this.toolButton('新增线', $r('sys.symbol.road_lanes_badge_minus'), MAP_TOOL_EDIT_ADD_LINE)
              this.toolButton('新增面', $r('sys.symbol.layer'), MAP_TOOL_EDIT_ADD_POLYGON)
            }
            Row({ space: 8 }) {
              this.toolButton('移动节点', $r('sys.symbol.hand_tap'), MAP_TOOL_EDIT_MOVE_NODE)
              this.toolButton('删除节点', $r('sys.symbol.trash'), MAP_TOOL_EDIT_DELETE_NODE)
              this.commandButton('复制所选要素', VECTOR_EDIT_COMMAND_COPY)
            }
            Row({ space: 8 }) {
              this.toolButton('框选', $r('sys.symbol.square_dashed'), MAP_TOOL_SELECT_BOX)
              this.toolButton('套索', $r('sys.symbol.point_bottomleft_forward_to_point_topright_scurvepath'),
                MAP_TOOL_SELECT_LASSO)
              this.toolButton('多边形选择', $r('sys.symbol.square'), MAP_TOOL_SELECT_POLYGON)
            }
            Row({ space: 8 }) {
              this.toolButton('草图切割', $r('sys.symbol.square_and_cut'), MAP_TOOL_EDIT_CUT_SKETCH)
              this.toolButton('追踪', $r('sys.symbol.point_bottomleft_forward_to_point_topright_scurvepath'),
                MAP_TOOL_EDIT_TRACE)
              this.toolButton('平行线', $r('sys.symbol.equals'), MAP_TOOL_EDIT_PARALLEL)
            }
            Row({ space: 8 }) {
              this.toolButton('垂线', $r('sys.symbol.square_slash'), MAP_TOOL_EDIT_PERPENDICULAR)
              this.toolButton('正交约束', $r('sys.symbol.square'), MAP_TOOL_EDIT_ORTHOGONAL)
              Blank().layoutWeight(1)
            }

            Column({ space: 8 }) {
              Row({ space: 8 }) {
                this.commandButton('撤销', VECTOR_EDIT_COMMAND_UNDO)
                this.commandButton('重做', VECTOR_EDIT_COMMAND_REDO)
                this.commandButton('切割', VECTOR_EDIT_COMMAND_CUT)
                this.commandButton('合并', VECTOR_EDIT_COMMAND_MERGE)
                this.commandButton('删除所选要素', VECTOR_EDIT_COMMAND_DELETE_FEATURE)
              }
              Row({ space: 8 }) {
                Text(this.snapEnabled ? '吸附：开' : '吸附：关')
                  .height(28)
                  .padding({ left: 10, right: 10 })
                  .fontSize(12)
                  .fontColor(this.snapEnabled ? $r('app.color.gn_green_700') : $r('app.color.gn_text_muted'))
                  .backgroundColor(this.snapEnabled ? $r('app.color.gn_selected_row') : $r('app.color.gn_pane'))
                  .borderRadius(4)
                  .onClick(() => {
                    this.snapEnabled = !this.snapEnabled;
                    this.refreshDialogUi();
                    this.saveSnappingConfiguration();
                    this.onEditCommand(VECTOR_EDIT_COMMAND_SNAP);
                  })
                TextInput({ text: this.snapTolerance, placeholder: '吸附像素' })
                  .height(30)
                  .fontSize(12)
                  .backgroundColor($r('app.color.gn_pane'))
                  .width(120)
                  .onChange((value: string) => {
                    this.snapTolerance = value;
                    this.saveSnappingConfiguration();
                  })
                Text('切割、合并、吸附会直接调用 QGIS 几何编辑接口并刷新图层。')
                  .fontSize(12)
                  .fontColor($r('app.color.gn_text_muted'))
                  .layoutWeight(1)
              }
              Row({ space: 8 }) {
                Text('端点优先 ' + this.snapEndpointPriority.toString())
                  .fontSize(11)
                  .onClick(() => {
                    this.snapEndpointPriority = (this.snapEndpointPriority + 1) % 3;
                    this.saveSnappingConfiguration();
                  })
                Text('顶点优先 ' + this.snapVertexPriority.toString())
                  .fontSize(11)
                  .onClick(() => {
                    this.snapVertexPriority = (this.snapVertexPriority + 1) % 3;
                    this.saveSnappingConfiguration();
                  })
                Text('线段优先 ' + this.snapSegmentPriority.toString())
                  .fontSize(11)
                  .onClick(() => {
                    this.snapSegmentPriority = (this.snapSegmentPriority + 1) % 3;
                    this.saveSnappingConfiguration();
                  })
                Text(this.snapCrossLayer ? '跨图层：开' : '跨图层：关')
                  .fontSize(11)
                  .onClick(() => {
                    this.snapCrossLayer = !this.snapCrossLayer;
                    this.saveSnappingConfiguration();
                  })
                Text(this.snapSpatialIndex ? '空间索引：开' : '空间索引：关')
                  .fontSize(11)
                  .onClick(() => {
                    this.snapSpatialIndex = !this.snapSpatialIndex;
                    this.saveSnappingConfiguration();
                  })
              }
            }
            .padding(14)
            .borderRadius(6)
            .backgroundColor($r('app.color.gn_paper'))
            .border({ width: 1, color: $r('app.color.gn_line') })
          }
          .padding(14)
        }.width('100%').height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
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
          title: { mainTitle: '矢量编辑' },
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
      .bindToScrollable([this.scroller])
    }
    .width('100%').height('100%')
  }

  build() {
    Row().width(0).height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        width: 900,
        height: 690,
        detents: [690],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}

@Component
export struct AttributeEditSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @State isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onAttributeEdited: () => void = () => {};
  onEditSessionCommand: (command: number) => void = () => {};
  onEnsureEditSession: () => boolean = () => false;
  @State private featureId: string = '';
  @State private fieldName: string = '';
  @State private fieldValue: string = '';
  @State private batchFilter: string = '';
  @State private newFieldName: string = '';
  @State private newFieldType: string = 'String';
  @State private calculatorMode: number = 0;
  @State private selectedTask: number = 0;
  @State private statusText: string = '属性编辑就绪';
  @State private uiRevision: number = 0;

  onTrigger(): void {
    this.isShow = true;
  }

  private refreshDialogUi(): void {
    this.uiRevision++;
  }

  private getActiveLayer(): GisLoadedLayer | undefined {
    return getGisService().getActiveLayer();
  }

  private activeFeatureId(): string {
    if (this.featureId.length > 0) {
      return this.featureId;
    }
    let layer = this.getActiveLayer();
    if (layer !== undefined && layer.features.length > 0) {
      return layer.features[0].featureId;
    }
    return '';
  }

  private activeFieldName(): string {
    if (this.fieldName.length > 0) {
      return this.fieldName;
    }
    let layer = this.getActiveLayer();
    if (layer !== undefined && layer.info.fields.length > 0) {
      return layer.info.fields[0].name;
    }
    return '';
  }

  private applyResult(result: GisOperationResult): void {
    if (result.ok) {
      this.statusText = result.message;
      this.onAttributeEdited();
    } else {
      this.statusText = '失败：' + result.message;
    }
  }

  private updateSingleValue(): void {
    if (!this.onEnsureEditSession()) {
      return;
    }
    this.applyResult(getGisService().updateFeatureAttribute(getGisService().getActiveLayerIndex(),
      this.activeFeatureId(), this.activeFieldName(), this.fieldValue));
  }

  private batchAssign(): void {
    if (!this.onEnsureEditSession()) {
      return;
    }
    this.applyResult(getGisService().batchAssignAttribute(getGisService().getActiveLayerIndex(),
      this.activeFieldName(), this.batchFilter, this.fieldValue));
  }

  private addField(): void {
    if (!this.onEnsureEditSession()) {
      return;
    }
    this.applyResult(getGisService().addLayerField(getGisService().getActiveLayerIndex(),
      this.newFieldName, this.newFieldType));
  }

  private deleteField(): void {
    if (!this.onEnsureEditSession()) {
      return;
    }
    this.applyResult(getGisService().deleteLayerField(getGisService().getActiveLayerIndex(), this.activeFieldName()));
  }

  private calculateField(): void {
    if (!this.onEnsureEditSession()) {
      return;
    }
    this.applyResult(getGisService().calculateField(getGisService().getActiveLayerIndex(), this.activeFieldName(),
      this.calculatorMode, this.fieldValue));
  }

  private fieldValuePlaceholder(): string {
    if (this.calculatorMode === 4) {
      return 'QGIS 表达式，例如 round($area, 2)';
    }
    return '字段值 / 计算常量';
  }

  @Builder
  fieldChip(field: GisFieldInfo) {
    Text(field.name)
      .height(26)
      .padding({ left: 9, right: 9 })
      .fontSize(12)
      .fontColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(this.activeFieldName() === field.name ? $r('app.color.gn_blue_100') : $r('app.color.gn_pane'))
      .borderRadius(4)
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.fieldName = field.name;
        this.refreshDialogUi();
      })
  }

  @Builder
  calcChip(label: string, mode: number) {
    Text(label)
      .height(26)
      .padding({ left: 9, right: 9 })
      .fontSize(12)
      .fontColor(this.calculatorMode === mode ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundColor(this.calculatorMode === mode ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(4)
      .onClick(() => {
        this.calculatorMode = mode;
        this.refreshDialogUi();
      })
  }

  @Builder
  taskButton(label: string, detail: string, task: number, icon: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.selectedTask === task ? $r('app.color.gn_blue_800') :
            $r('sys.color.icon_secondary')])
        Column({ space: 2 }) {
          Text(label)
            .fontSize(12)
            .fontWeight(this.selectedTask === task ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.selectedTask === task ? $r('app.color.gn_blue_800') :
              $r('app.color.gn_text_primary'))
          Text(detail)
            .fontSize(9)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .height(54)
    .padding({ left: 10, right: 10 })
    .backgroundColor(this.selectedTask === task ? $r('app.color.gn_blue_100') : $r('app.color.gn_paper'))
    .borderRadius(6)
    .border({
      width: 1,
      color: this.selectedTask === task ? $r('app.color.gn_blue_800') : $r('app.color.gn_line')
    })
    .onClick(() => {
      this.selectedTask = task;
      this.refreshDialogUi();
    })
  }

  @Builder
  inputLabel(label: string) {
    Text(label)
      .fontSize(11)
      .fontColor($r('app.color.gn_text_muted'))
      .width('100%')
  }

  @Builder
  sessionButton(label: ResourceStr, command: number) {
    Button(label, { type: ButtonType.Capsule, stateEffect: true })
      .height(30)
      .fontSize(12)
      .fontColor($r('app.color.gn_blue_800'))
      .backgroundColor($r('app.color.gn_blue_100'))
      .onClick(() => {
        this.onEditSessionCommand(command);
      })
  }

  @Builder
  operationPanel() {
    Column({ space: 10 }) {
      if (this.selectedTask === 0) {
        Text('修改单个要素')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text('指定要素 FID，并修改当前选中字段的值。')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Row({ space: 10 }) {
          Column({ space: 5 }) {
            this.inputLabel('要素 FID')
            TextInput({ text: this.activeFeatureId(), placeholder: 'FID' })
              .height(36)
              .fontSize(12)
              .backgroundColor($r('app.color.gn_pane'))
              .onChange((value: string) => {
                this.featureId = value;
              })
          }
          .width(150)
          Column({ space: 5 }) {
            this.inputLabel('新字段值')
            TextInput({ text: this.fieldValue, placeholder: this.fieldValuePlaceholder() })
              .height(36)
              .fontSize(12)
              .backgroundColor($r('app.color.gn_pane'))
              .onChange((value: string) => {
                this.fieldValue = value;
              })
          }
          .layoutWeight(1)
        }
        Button('保存字段值', { type: ButtonType.Capsule, stateEffect: true })
          .height(36)
          .width(160)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.gn_blue_800'))
          .onClick(() => {
            this.updateSingleValue();
          })
      } else if (this.selectedTask === 1) {
        Text('批量赋值')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text('先填写筛选条件，再为符合条件的要素统一赋值。')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        this.inputLabel('筛选条件')
        TextInput({ text: this.batchFilter, placeholder: '文本筛选；qgis: 开头可输入 QGIS 表达式' })
          .height(36)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.batchFilter = value;
          })
        this.inputLabel('统一字段值')
        TextInput({ text: this.fieldValue, placeholder: '批量写入的字段值' })
          .height(36)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.fieldValue = value;
          })
        Button('执行批量赋值', { type: ButtonType.Capsule, stateEffect: true })
          .height(36)
          .width(160)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.gn_blue_800'))
          .onClick(() => {
            this.batchAssign();
          })
      } else if (this.selectedTask === 2) {
        Text('字段结构')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text('新增字段，或删除上方当前选中的字段。删除操作不可撤销。')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Row({ space: 10 }) {
          Column({ space: 5 }) {
            this.inputLabel('新字段名')
            TextInput({ text: this.newFieldName, placeholder: '例如 category' })
              .height(36)
              .fontSize(12)
              .backgroundColor($r('app.color.gn_pane'))
              .onChange((value: string) => {
                this.newFieldName = value;
              })
          }
          .layoutWeight(1)
          Column({ space: 5 }) {
            this.inputLabel('字段类型')
            TextInput({ text: this.newFieldType, placeholder: 'String' })
              .height(36)
              .fontSize(12)
              .backgroundColor($r('app.color.gn_pane'))
              .onChange((value: string) => {
                this.newFieldType = value;
              })
          }
          .width(150)
        }
        Row({ space: 10 }) {
          Button('新增字段', { type: ButtonType.Capsule, stateEffect: true })
            .height(36)
            .width(140)
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.gn_blue_800'))
            .onClick(() => {
              this.addField();
            })
          Button('删除当前字段', { type: ButtonType.Capsule, stateEffect: true })
            .height(36)
            .width(150)
            .fontSize(12)
            .fontColor($r('app.color.gn_red_700'))
            .backgroundColor($r('app.color.gn_error_bg'))
            .onClick(() => {
              this.deleteField();
            })
        }
      } else {
        Text('字段计算器')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .width('100%')
        Text('选择计算方式，结果将写入上方当前选中的字段。')
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          this.calcChip('常量', 0)
          this.calcChip('FID', 1)
          this.calcChip('几何面积', 2)
          this.calcChip('几何长度', 3)
          this.calcChip('QGIS 表达式', 4)
        }
        this.inputLabel(this.calculatorMode === 4 ? 'QGIS 表达式' : '计算常量')
        TextInput({ text: this.fieldValue, placeholder: this.fieldValuePlaceholder() })
          .height(36)
          .fontSize(12)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.fieldValue = value;
          })
        Button('执行字段计算', { type: ButtonType.Capsule, stateEffect: true })
          .height(36)
          .width(160)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.gn_blue_800'))
          .onClick(() => {
            this.calculateField();
          })
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(7)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        if (this.getActiveLayer() === undefined) {
          Column() {
            Text('当前没有已加载图层')
              .fontSize(16)
              .fontColor($r('app.color.gn_text_primary'))
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll(this.scroller) {
            Column({ space: 12 }) {
              Blank().height(80).width('100%')
              Text(this.uiRevision.toString())
                .width(0)
                .height(0)
                .fontSize(0)
                .opacity(0)
              Text((this.getActiveLayer() as GisLoadedLayer).info.name)
                .width('100%')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.gn_text_primary'))
              Text($r('app.string.gn_edit_session_description'))
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
              Row({ space: 8 }) {
                this.sessionButton($r('app.string.gn_edit_session_begin'), VECTOR_EDIT_COMMAND_BEGIN_SESSION)
                this.sessionButton($r('app.string.gn_edit_session_commit'), VECTOR_EDIT_COMMAND_COMMIT_SESSION)
                this.sessionButton($r('app.string.gn_edit_session_rollback'), VECTOR_EDIT_COMMAND_ROLLBACK_SESSION)
              }
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach((this.getActiveLayer() as GisLoadedLayer).info.fields, (field: GisFieldInfo) => {
                  this.fieldChip(field)
                }, (field: GisFieldInfo) => 'attr-edit-field:' + field.name)
              }
              Text('当前字段：' + this.activeFieldName())
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
              Row({ space: 8 }) {
                this.taskButton('单个要素', '按 FID 修改', 0, $r('sys.symbol.square_and_pencil'))
                this.taskButton('批量赋值', '按条件更新', 1, $r('sys.symbol.list_bullet'))
                this.taskButton('字段结构', '新增或删除', 2, $r('sys.symbol.plus_square_fill'))
                this.taskButton('字段计算', '常量或表达式', 3, $r('sys.symbol.calculator'))
              }
              .width('100%')
              this.operationPanel()
              Text('状态：' + this.statusText)
                .fontSize(12)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
            }
            .padding(14)
          }.width('100%').height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
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
          title: { mainTitle: '属性编辑' },
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
      .bindToScrollable([this.scroller])
    }
    .width('100%').height('100%')
  }

  build() {
    Row().width(0).height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        width: 900,
        height: 690,
        detents: [690],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}
