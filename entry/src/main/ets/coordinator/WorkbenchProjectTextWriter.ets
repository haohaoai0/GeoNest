import { GisService } from '../gis/GisService';
import { WorkbenchTextService } from '@geonest/workbench';

export class WorkbenchProjectTextWriter {
  private gisService: GisService;

  constructor(gisService: GisService) {
    this.gisService = gisService;
  }

  write(magic: string, projectName: string, projectOwner: string, projectCrs: string, projectMapName: string,
    projectWorkspaceName: string, projectDescription: string, basemapMode: number, basemapDatumMode: number,
    layerPaths: string[]): string {
    let text: string = magic + '\n';
    text += 'projectFormatVersion=2\n';
    text += 'projectName=' + WorkbenchTextService.sanitizeLineValue(projectName) + '\n';
    text += 'projectOwner=' + WorkbenchTextService.sanitizeLineValue(projectOwner) + '\n';
    text += 'projectCrs=' + WorkbenchTextService.sanitizeLineValue(projectCrs) + '\n';
    text += 'projectMapName=' + WorkbenchTextService.sanitizeLineValue(projectMapName) + '\n';
    text += 'projectWorkspaceName=' + WorkbenchTextService.sanitizeLineValue(projectWorkspaceName) + '\n';
    text += 'projectDescription=' + WorkbenchTextService.sanitizeLineValue(projectDescription) + '\n';
    text += 'basemapMode=' + basemapMode.toString() + '\n';
    text += 'basemapDatumMode=' + basemapDatumMode.toString() + '\n';
    text += 'activeLayerIndex=' + this.gisService.getActiveLayerIndex().toString() + '\n';
    text += 'layerCount=' + this.gisService.getLayerCount().toString() + '\n';
    for (let i: number = 0; i < this.gisService.getLayerCount(); i++) {
      let layer = this.gisService.getLayer(i);
      if (layer !== undefined) {
        let prefix: string = 'layer.' + i.toString() + '.';
        let style = layer.style;
        let layerPath: string = layer.sourcePath;
        if (i < layerPaths.length && layerPaths[i].length > 0) {
          layerPath = layerPaths[i];
        }
        text += prefix + 'path=' + WorkbenchTextService.sanitizeLineValue(layerPath) + '\n';
        text += prefix + 'visible=' + (layer.visible ? 'true' : 'false') + '\n';
        text += prefix + 'styleVersion=1\n';
        text += prefix + 'pointColor=' + WorkbenchTextService.sanitizeLineValue(style.pointColor) + '\n';
        text += prefix + 'lineColor=' + WorkbenchTextService.sanitizeLineValue(style.lineColor) + '\n';
        text += prefix + 'fillColor=' + WorkbenchTextService.sanitizeLineValue(style.fillColor) + '\n';
        text += prefix + 'strokeColor=' + WorkbenchTextService.sanitizeLineValue(style.strokeColor) + '\n';
        text += prefix + 'lineWidth=' + style.lineWidth.toString() + '\n';
        text += prefix + 'pointRadius=' + style.pointRadius.toString() + '\n';
        text += prefix + 'rendererMode=' + style.rendererMode.toString() + '\n';
        text += prefix + 'rendererField=' + WorkbenchTextService.sanitizeLineValue(style.rendererField) + '\n';
        text += prefix + 'colorRamp=' + style.colorRamp.toString() + '\n';
        text += prefix + 'linePattern=' + style.linePattern.toString() + '\n';
        text += prefix + 'fillPattern=' + style.fillPattern.toString() + '\n';
        text += prefix + 'opacity=' + style.opacity.toString() + '\n';
        text += prefix + 'symbolName=' + WorkbenchTextService.sanitizeLineValue(style.symbolName) + '\n';
        text += prefix + 'labelEnabled=' + (style.labelEnabled ? 'true' : 'false') + '\n';
        text += prefix + 'labelField=' + WorkbenchTextService.sanitizeLineValue(style.labelField) + '\n';
        text += prefix + 'labelSize=' + style.labelSize.toString() + '\n';
        text += prefix + 'labelColor=' + WorkbenchTextService.sanitizeLineValue(style.labelColor) + '\n';
        text += prefix + 'labelHalo=' + (style.labelHalo ? 'true' : 'false') + '\n';
        text += prefix + 'labelAvoidance=' + (style.labelAvoidance ? 'true' : 'false') + '\n';
        text += prefix + 'labelMinScale=' + style.labelMinScale.toString() + '\n';
        text += prefix + 'labelMaxScale=' + style.labelMaxScale.toString() + '\n';
        text += prefix + 'rasterBandMode=' + style.rasterBandMode.toString() + '\n';
        text += prefix + 'rasterStretchMode=' + style.rasterStretchMode.toString() + '\n';
        text += prefix + 'rasterColorRamp=' + style.rasterColorRamp.toString() + '\n';
        text += prefix + 'rasterOpacity=' + style.rasterOpacity.toString() + '\n';
        text += prefix + 'rasterNoData=' + WorkbenchTextService.sanitizeLineValue(style.rasterNoData) + '\n';
        text += prefix + 'rasterTransparentColor=' +
          WorkbenchTextService.sanitizeLineValue(style.rasterTransparentColor) + '\n';
        text += prefix + 'rasterHillshade=' + (style.rasterHillshade ? 'true' : 'false') + '\n';
      }
    }
    return text;
  }
}
