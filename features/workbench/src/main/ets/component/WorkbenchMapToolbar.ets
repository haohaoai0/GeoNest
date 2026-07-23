import {
  MAP_TOOL_IDENTIFY,
  MAP_TOOL_MEASURE_ANGLE,
  MAP_TOOL_MEASURE_AREA,
  MAP_TOOL_MEASURE_DISTANCE,
  MAP_TOOL_PICK_COORDINATE,
  MAP_TOOL_SELECT_MULTIPLE,
  MAP_TOOL_EDIT_ADD_POINT,
  MAP_TOOL_EDIT_ADD_LINE,
  MAP_TOOL_EDIT_ADD_POLYGON,
  MAP_TOOL_EDIT_MOVE_NODE,
  MAP_TOOL_EDIT_DELETE_NODE
} from '@geonest/common';
import { MaterialStyle } from '@geonest/common';

const MAP_VIEW_DATA: number = 0;
const MAP_VIEW_LAYOUT: number = 1;

@Component
export struct WorkbenchMapToolbar {
  @Prop mapTitle: string = '';
  @Prop mapTitleRevision: number = 0;
  @Prop mapToolMode: number = 0;
  @Prop mapViewMode: number = MAP_VIEW_DATA;
  @Prop scene3DVisible: boolean = false;
  @Prop itemRadius: number = 6;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  onSelectTool: (toolMode: number) => void = (toolMode: number): void => {};
  onSelectViewMode: (mode: number) => void = (mode: number): void => {};
  onToggleScene3D: () => void = (): void => {};
  onOpenLayoutProperties: () => void = (): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon).fontSize(sizeValue).fontColor([color])
  }

  @Builder
  mapViewModeButton(label: ResourceStr, icon: Resource, mode: number) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 4 }) {
        this.symbol(icon, this.mapViewMode === mode ? $r('app.color.gn_blue_800') :
          $r('sys.color.icon_secondary'), 13)
        Text(label)
          .fontSize(11)
          .fontWeight(this.mapViewMode === mode ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.mapViewMode === mode ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      }
    }
    .height(26)
    .padding({ left: 8, right: 8 })
    .backgroundColor(this.mapViewMode === mode ? $r('app.color.gn_blue_100') : Color.Transparent)
    .borderRadius(this.itemRadius)
    .onClick(() => {
      this.onSelectViewMode(mode);
    })
  }

  @Builder
  mapToolChip(label: ResourceStr, toolMode: number) {
    Text(label)
      .height(24)
      .padding({ left: 9, right: 9 })
      .fontSize(11)
      .fontWeight(this.mapToolMode === toolMode ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.mapToolMode === toolMode ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
      .backgroundBlurStyle(MaterialStyle.componentBlurStyle())
      .backgroundColor(this.mapToolMode === toolMode ? $r('app.color.gn_blue_100') : Color.Transparent)
      .borderRadius(this.itemRadius)
      .onClick(() => {
        this.onSelectTool(toolMode);
      })
  }

  build() {
    Row() {
      Row({ space: 6 }) {
        this.symbol($r('sys.symbol.map'), $r('app.color.gn_blue_800'), 16)
        Text(this.mapTitle)
          .fontSize(13)
          .fontColor($r('app.color.gn_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .key('title:' + this.mapTitleRevision.toString())
      }
      .height(32)
      .padding({ left: 12, right: 14 })
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: { right: 1 }, color: $r('app.color.gn_line') })
      Scroll() {
        Row({ space: 6 }) {
          this.mapToolChip($r('app.string.gn_tool_identify'), MAP_TOOL_IDENTIFY)
          this.mapToolChip($r('app.string.gn_tool_select_multiple'), MAP_TOOL_SELECT_MULTIPLE)
          this.mapToolChip($r('app.string.gn_measure_distance'), MAP_TOOL_MEASURE_DISTANCE)
          this.mapToolChip($r('app.string.gn_measure_area'), MAP_TOOL_MEASURE_AREA)
          this.mapToolChip($r('app.string.gn_measure_angle'), MAP_TOOL_MEASURE_ANGLE)
          this.mapToolChip($r('app.string.gn_pick_coordinate'), MAP_TOOL_PICK_COORDINATE)
          this.mapToolChip('加点', MAP_TOOL_EDIT_ADD_POINT)
          this.mapToolChip('加线', MAP_TOOL_EDIT_ADD_LINE)
          this.mapToolChip('加面', MAP_TOOL_EDIT_ADD_POLYGON)
          this.mapToolChip('移节点', MAP_TOOL_EDIT_MOVE_NODE)
          this.mapToolChip('删节点', MAP_TOOL_EDIT_DELETE_NODE)
        }
        .padding({ left: 10, right: 10 })
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      Row({ space: 4 }) {
        this.mapViewModeButton($r('app.string.gn_data_view'), $r('sys.symbol.map'), MAP_VIEW_DATA)
        this.mapViewModeButton($r('app.string.gn_layout_view'), $r('sys.symbol.doc_text'), MAP_VIEW_LAYOUT)
        Button(this.scene3DVisible ? $r('app.string.gn_scene_2d_view') : $r('app.string.gn_scene_3d_view'),
          { type: ButtonType.Capsule, stateEffect: true })
          .height(26)
          .fontSize(11)
          .onClick((): void => {
            this.onToggleScene3D();
          })
        if (this.mapViewMode === MAP_VIEW_LAYOUT) {
          Button($r('app.string.gn_layout_properties'), { type: ButtonType.Capsule, stateEffect: true })
            .height(26)
            .fontSize(11)
            .fontColor($r('app.color.gn_blue_800'))
            .backgroundColor($r('app.color.gn_blue_100'))
            .onClick(() => {
              this.onOpenLayoutProperties();
            })
        }
      }
      .height(32)
      .padding({ left: 6, right: 8 })
      .border({ width: { left: 1 }, color: $r('app.color.gn_line') })
    }
    .height(34)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.surfaceColor)
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }
}
