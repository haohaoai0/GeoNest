import { MaterialStyle } from '@geonest/common';
import { WorkbenchStatusSegment } from './WorkbenchStatusSegment';

@Component
export struct WorkbenchMapStatusBar {
  @Prop viewportScale: string = '';
  @Prop viewportCoordinateText: string = '';
  @Prop mapReferenceStatus: string = '';
  @Prop catalogSummary: string = '';
  @Prop basemapName: string = '';
  @Prop basemapDatumName: string = '';
  @Prop basemapStatus: string = '';
  @Prop measurementStatus: string = '';
  @Prop dataLoadStatus: string = '';
  @Prop editStatus: string = '';
  @Prop selectedFeatureStatus: string = '';
  @Prop nativeBridgeVersion: string = '';
  @Prop basemapActive: boolean = false;
  @Prop externalBasemap: boolean = false;
  @Prop projectDirty: boolean = false;
  @Prop recoveryPointAvailable: boolean = false;
  @Prop nativeBridgeAvailable: boolean = false;
  @Prop basemapStatusColor: ResourceColor = Color.Transparent;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  @Prop itemRadius: number = 6;

  @Builder
  segment(icon: Resource, label: ResourceStr, color: ResourceColor) {
    WorkbenchStatusSegment({
      icon: icon,
      label: label,
      color: color,
      radiusValue: this.itemRadius
    })
  }

  build() {
    Scroll(undefined) {
      Row({ space: 6 }) {
        this.segment($r('sys.symbol.map'), this.viewportScale, $r('app.color.gn_text_primary'))
        this.segment($r('sys.symbol.location_up'), this.viewportCoordinateText,
          $r('app.color.gn_text_primary'))
        this.segment($r('sys.symbol.doc_text'), this.mapReferenceStatus, $r('app.color.gn_text_muted'))
        this.segment($r('sys.symbol.layer'), this.catalogSummary, $r('app.color.gn_text_muted'))
        this.segment($r('sys.symbol.map'), this.basemapName,
          this.basemapActive ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
        if (this.externalBasemap) {
          this.segment($r('sys.symbol.location_up'), this.basemapDatumName, $r('app.color.gn_blue_800'))
        }
        if (this.basemapStatus.length > 0) {
          this.segment($r('sys.symbol.exclamationmark_triangle'), this.basemapStatus, this.basemapStatusColor)
        }
        if (this.measurementStatus.length > 0) {
          this.segment($r('sys.symbol.plus_magnifyingglass'), this.measurementStatus,
            $r('app.color.gn_orange_700'))
        }
        if (this.dataLoadStatus.length > 0) {
          this.segment($r('sys.symbol.arrow_clockwise'), this.dataLoadStatus, $r('app.color.gn_text_muted'))
        }
        if (this.editStatus.length > 0) {
          this.segment($r('sys.symbol.wrench_arrow_counterclockwise'), this.editStatus,
            $r('app.color.gn_blue_800'))
        }
        this.segment($r('sys.symbol.checkmark_square'), this.selectedFeatureStatus,
          $r('app.color.gn_text_muted'))
        if (this.projectDirty) {
          this.segment($r('sys.symbol.doc_text_badge_clock'), $r('app.string.gn_workbench_dirty_state'),
            $r('app.color.gn_orange_700'))
        } else {
          this.segment($r('sys.symbol.doc_plaintext_and_checkmark'), $r('app.string.gn_workbench_clean_state'),
            $r('app.color.gn_green_700'))
        }
        if (this.recoveryPointAvailable && this.projectDirty) {
          this.segment($r('sys.symbol.doc_plaintext_and_checkmark'), $r('app.string.gn_recovery_saved_status'),
            $r('app.color.gn_green_700'))
        }
        if (this.nativeBridgeAvailable) {
          this.segment($r('sys.symbol.checkmark_circle'), this.nativeBridgeVersion,
            $r('app.color.gn_blue_800'))
        } else {
          this.segment($r('sys.symbol.exclamationmark_triangle'),
            $r('app.string.gn_workbench_native_core_unavailable'), $r('app.color.gn_orange_700'))
        }
      }
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .height(30)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.surfaceColor)
  }
}
