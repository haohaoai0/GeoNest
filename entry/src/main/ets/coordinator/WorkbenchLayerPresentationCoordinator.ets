import { GisLoadedLayer, qgisCategoryTotal, qgisRampColor } from '../gis/GisService';

export class WorkbenchLayerPresentationCoordinator {
  rendererText(layer: GisLoadedLayer): string {
    if (layer.style.rendererMode === 1) {
      if (layer.style.rendererField.length > 0) {
        return '唯一值：' + layer.style.rendererField;
      }
      return '唯一值渲染';
    }
    if (layer.style.rendererMode === 2) {
      if (layer.style.rendererField.length > 0) {
        return '分级色带：' + layer.style.rendererField;
      }
      return '分级色带';
    }
    if (layer.style.rendererMode === 3) {
      if (layer.style.rendererField.length > 0) {
        return '表达式规则：' + layer.style.rendererField;
      }
      return '表达式规则';
    }
    return layer.style.symbolName;
  }

  labelText(layer: GisLoadedLayer): string {
    if (!layer.style.labelEnabled) {
      return '标注关闭';
    }
    if (layer.style.labelField.length > 0) {
      if (layer.style.labelField.startsWith('expr:')) {
        let expressionText: string = layer.style.labelField.substring(5).trim();
        if (expressionText.length > 0) {
          return '表达式标注：' + expressionText;
        }
        return '表达式标注';
      }
      return '标注字段：' + layer.style.labelField;
    }
    return '标注开启 · 未选择字段';
  }

  sourcePathText(path: string): string {
    if (path.length === 0) {
      return '工程内图层';
    }
    return path;
  }

  private rampTotal(layer: GisLoadedLayer): number {
    if (layer.style.rendererMode === 1) {
      return qgisCategoryTotal(layer, layer.style.rendererField);
    }
    if (layer.style.rendererMode === 2) {
      return 5;
    }
    if (layer.style.rendererMode === 3) {
      return 2;
    }
    return 1;
  }

  displayColor(layer: GisLoadedLayer): string {
    if (layer.info.legendColor.length > 0) {
      return layer.info.legendColor;
    }
    if (layer.style.rendererMode === 1 || layer.style.rendererMode === 2 || layer.style.rendererMode === 3) {
      return qgisRampColor(layer.style.colorRamp, 0, this.rampTotal(layer));
    }
    if (layer.info.geometryType === 1) {
      return layer.style.pointColor;
    }
    if (layer.info.geometryType === 2) {
      return layer.style.lineColor;
    }
    return layer.style.fillColor;
  }
}
