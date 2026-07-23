import {
  BASEMAP_DATUM_AUTO,
  BASEMAP_VECTOR,
  MAP_COMMAND_NONE,
  MAP_TOOL_IDENTIFY
} from '@geonest/common';
import { window } from '@kit.ArkUI';
import { GisMapCanvas, MapViewport } from '../component/GisMapCanvas';
import { GisService, GisLoadedLayer, getGisService } from '../gis/GisService';
import { GisCoordinate } from '../model/GeoNestModels';
import {
  GN_LAYER_REVISION_KEY,
  GN_MULTI_MAP_LINK_ENABLED_KEY,
  GN_MULTI_MAP_VIEWPORT_CENTER_X_KEY,
  GN_MULTI_MAP_VIEWPORT_CENTER_Y_KEY,
  GN_MULTI_MAP_VIEWPORT_REVISION_KEY,
  GN_MULTI_MAP_VIEWPORT_SCALE_KEY,
  GN_MULTI_MAP_VIEWPORT_SOURCE_KEY
} from '../model/MultiMapState';

@Entry
@Component
struct MapCompare {
  @StorageLink(GN_LAYER_REVISION_KEY) @Watch('onLayerRevisionChanged') private sharedLayerRevision: number = 0;
  @StorageLink(GN_MULTI_MAP_LINK_ENABLED_KEY) private linkedMapViewEnabled: boolean = true;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_REVISION_KEY) @Watch('onLinkedViewportChanged')
  private linkedViewportRevision: number = 0;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_CENTER_X_KEY) private linkedViewportCenterX: number = 0.5;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_CENTER_Y_KEY) private linkedViewportCenterY: number = 0.5;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_SCALE_KEY) private linkedViewportScale: number = 100.0;
  @StorageLink(GN_MULTI_MAP_VIEWPORT_SOURCE_KEY) private linkedViewportSource: string = '';
  @State private renderKey: number = 0;
  @State private viewportApplyRevision: number = 0;
  @State private viewportText: string = '等待主地图视图';
  @State private basemapStatus: string = '';

  private gisService: GisService = getGisService();
  private localViewportSourceId: string = 'compare';

  private buildLoadedLayers(): GisLoadedLayer[] {
    let result: GisLoadedLayer[] = [];
    for (let i: number = 0; i < this.gisService.getLayerCount(); i++) {
      let layer: GisLoadedLayer | undefined = this.gisService.getLayer(i);
      if (layer !== undefined) {
        result.push(layer);
      }
    }
    return result;
  }

  private onLayerRevisionChanged(): void {
    this.renderKey++;
  }

  private onLinkedViewportChanged(): void {
    if (!this.linkedMapViewEnabled) {
      return;
    }
    if (this.linkedViewportSource === this.localViewportSourceId) {
      return;
    }
    if (this.linkedViewportScale <= 0.000000001) {
      return;
    }
    this.viewportApplyRevision++;
  }

  private publishViewport(viewport: MapViewport): void {
    if (!this.linkedMapViewEnabled) {
      return;
    }
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_CENTER_X_KEY, viewport.centerX);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_CENTER_Y_KEY, viewport.centerY);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_SCALE_KEY, viewport.scale);
    AppStorage.setOrCreate<string>(GN_MULTI_MAP_VIEWPORT_SOURCE_KEY, this.localViewportSourceId);
    let revision: number | undefined = AppStorage.get<number>(GN_MULTI_MAP_VIEWPORT_REVISION_KEY);
    AppStorage.setOrCreate<number>(GN_MULTI_MAP_VIEWPORT_REVISION_KEY, revision === undefined ? 1 : revision + 1);
  }

  private onViewportChanged(viewport: MapViewport): void {
    this.viewportText = viewport.displayLongitude.toFixed(4) + ', ' + viewport.displayLatitude.toFixed(4) +
      ' · ' + viewport.scaleLabel;
    this.publishViewport(viewport);
  }

  private layerSummaryText(): string {
    let count: number = this.gisService.getLayerCount();
    if (count === 0) {
      return '没有业务图层，可从主地图拖拽或添加数据';
    }
    return count.toString() + ' 个共享图层 · ' + this.gisService.getTotalFeatureCount().toString() + ' 个要素';
  }

  private linkStatusText(): string {
    if (this.linkedMapViewEnabled) {
      return '视图联动';
    }
    return '独立视图';
  }

  private async closeSecondaryMapWindow(): Promise<void> {
    try {
      let mapWindow: window.Window = window.findWindow('GeoNestSecondMap');
      await mapWindow.destroyWindow();
    } catch (e) {
      console.error('closeSecondaryMapWindow failed: ' + String(e));
    }
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text($r('app.string.gn_compare_map_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
          Text(this.layerSummaryText())
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.linkStatusText())
          .height(26)
          .padding({ left: 10, right: 10 })
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.linkedMapViewEnabled ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
          .backgroundColor(this.linkedMapViewEnabled ? $r('app.color.gn_blue_100') : $r('app.color.gn_paper'))
          .borderRadius(13)

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(13)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .width(30)
        .height(30)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.gn_dialog_close'))
        .onClick(() => {
          this.closeSecondaryMapWindow();
        })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12 })

      Text(this.viewportText)
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
        .padding({ left: 14, right: 14 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Stack({ alignContent: Alignment.BottomStart }) {
        GisMapCanvas({
          layers: this.buildLoadedLayers(),
          basemapMode: BASEMAP_VECTOR,
          basemapDatumMode: BASEMAP_DATUM_AUTO,
          renderKey: this.renderKey + this.sharedLayerRevision,
          mapCommand: MAP_COMMAND_NONE,
          mapToolMode: MAP_TOOL_IDENTIFY,
          externalViewportKey: this.viewportApplyRevision,
          externalViewportCenterX: this.linkedViewportCenterX,
          externalViewportCenterY: this.linkedViewportCenterY,
          externalViewportScale: this.linkedViewportScale,
          onViewportChanged: (viewport: MapViewport) => {
            this.onViewportChanged(viewport);
          },
          onBasemapStatusChanged: (summary: string) => {
            this.basemapStatus = summary;
          },
          onSketchFeatureCreated: (_geometryType: number, _points: GisCoordinate[]) => {
          },
          onCutSketchCompleted: (_points: GisCoordinate[]) => {
          }
        })
          .width('100%')
          .height('100%')

        if (this.basemapStatus.length > 0) {
          Text(this.basemapStatus)
            .fontSize(11)
            .fontColor($r('app.color.gn_text_muted'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .margin({ left: 12, bottom: 12 })
            .backgroundColor($r('app.color.gn_pane'))
            .borderRadius(12)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .clip(true)
      .borderRadius(18)
      .border({ width: 1, color: $r('app.color.gn_line') })
      .margin({ left: 10, right: 10, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.gn_arc_window'))
  }
}
