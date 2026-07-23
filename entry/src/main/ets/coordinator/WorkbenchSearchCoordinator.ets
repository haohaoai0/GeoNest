import { GisLoadedLayer, GisService } from '../gis/GisService';
import {
  GlobalSearchCandidate,
  LayerDisplayItem,
  WorkbenchSearchViewModel
} from '@geonest/workbench';

type LayerTextResolver = (layer: GisLoadedLayer) => string;

export class WorkbenchSearchCoordinator {
  private gisService: GisService;
  private searchViewModel: WorkbenchSearchViewModel;
  private geometryNameResolver: LayerTextResolver;
  private referenceResolver: LayerTextResolver;
  private rendererResolver: LayerTextResolver;
  private labelResolver: LayerTextResolver;

  constructor(gisService: GisService, searchViewModel: WorkbenchSearchViewModel,
    geometryNameResolver: LayerTextResolver, referenceResolver: LayerTextResolver,
    rendererResolver: LayerTextResolver, labelResolver: LayerTextResolver) {
    this.gisService = gisService;
    this.searchViewModel = searchViewModel;
    this.geometryNameResolver = geometryNameResolver;
    this.referenceResolver = referenceResolver;
    this.rendererResolver = rendererResolver;
    this.labelResolver = labelResolver;
  }

  normalizedText(value: string): string {
    return this.searchViewModel.normalizedText(value);
  }

  matches(keyword: string, sourceText: string): boolean {
    return this.searchViewModel.matches(keyword, sourceText);
  }

  layerFieldSearchText(layer: GisLoadedLayer): string {
    let result: string = '';
    for (let i: number = 0; i < layer.info.fields.length; i++) {
      if (result.length > 0) {
        result += ' ';
      }
      result += layer.info.fields[i].name + ' ' + layer.info.fields[i].typeName;
    }
    return result;
  }

  layerSearchText(layer: GisLoadedLayer): string {
    return layer.info.name + ' ' + layer.info.crs + ' ' + layer.info.crsDescription + ' ' +
      layer.info.crsFriendlyName + ' ' + this.geometryNameResolver(layer) + ' ' +
      this.referenceResolver(layer) + ' ' + this.rendererResolver(layer) + ' ' +
      this.labelResolver(layer) + ' ' + layer.sourcePath + ' ' + this.layerFieldSearchText(layer);
  }

  matchesLayerItem(item: LayerDisplayItem, keyword: string): boolean {
    let sourceText: string = item.name + ' ' + item.crs + ' ' + item.sourcePath + ' ' + item.referenceText + ' ' +
      item.geometryText + ' ' + item.rendererText + ' ' + item.labelText + ' ' + item.fieldText;
    return this.matches(keyword, sourceText);
  }

  filterLayerItems(items: LayerDisplayItem[], searchText: string): LayerDisplayItem[] {
    let keyword: string = this.normalizedText(searchText);
    if (keyword.length === 0) {
      return items;
    }
    let result: LayerDisplayItem[] = [];
    for (let i: number = 0; i < items.length; i++) {
      if (this.matchesLayerItem(items[i], keyword)) {
        result.push(items[i]);
      }
    }
    return result;
  }

  buildLayerCandidate(layer: GisLoadedLayer, layerIndex: number, keySuffix: string): GlobalSearchCandidate {
    let item: GlobalSearchCandidate = new GlobalSearchCandidate();
    item.kind = 1;
    item.key = 'layer:' + layer.info.layerId + ':' + keySuffix;
    item.title = layer.info.name;
    item.category = '图层';
    item.layerIndex = layerIndex;
    item.geometryType = layer.info.geometryType;
    item.featureCount = layer.info.featureCount;
    item.crs = layer.info.crs;
    item.subtitle = this.geometryNameResolver(layer) + ' · ' + layer.info.featureCount.toString() + ' 要素';
    if (layer.info.crs.length > 0) {
      item.subtitle += ' · ' + layer.info.crs;
    }
    item.sourceText = this.layerSearchText(layer);
    return item;
  }

  buildLayerCandidates(keyword: string, maxCount: number, keySuffix: string): GlobalSearchCandidate[] {
    let items: GlobalSearchCandidate[] = [];
    for (let i: number = 0; i < this.gisService.getLayerCount(); i++) {
      if (items.length >= maxCount) {
        break;
      }
      let layer: GisLoadedLayer | undefined = this.gisService.getLayer(i);
      if (layer !== undefined && this.matches(keyword, this.layerSearchText(layer))) {
        items.push(this.buildLayerCandidate(layer, i, keySuffix));
      }
    }
    return items;
  }

  buildGlobalCandidates(searchText: string, maxCount: number, maxLayerCount: number,
    keySuffix: string): GlobalSearchCandidate[] {
    let keyword: string = this.normalizedText(searchText);
    let result: GlobalSearchCandidate[] = [];
    if (keyword.length === 0) {
      return result;
    }
    let layerCandidates: GlobalSearchCandidate[] = this.buildLayerCandidates(keyword, maxCount, keySuffix);
    let commandCandidates: GlobalSearchCandidate[] = this.searchViewModel.buildCommandCandidates(keyword);
    for (let i: number = 0; i < layerCandidates.length && i < maxLayerCount; i++) {
      if (result.length < maxCount) {
        result.push(layerCandidates[i]);
      }
    }
    for (let i: number = 0; i < commandCandidates.length; i++) {
      if (result.length < maxCount) {
        result.push(commandCandidates[i]);
      }
    }
    for (let i: number = maxLayerCount; i < layerCandidates.length; i++) {
      if (result.length < maxCount) {
        result.push(layerCandidates[i]);
      }
    }
    return result;
  }

  firstLayerIndex(keyword: string): number {
    for (let i: number = 0; i < this.gisService.getLayerCount(); i++) {
      let layer: GisLoadedLayer | undefined = this.gisService.getLayer(i);
      if (layer !== undefined && this.matches(keyword, this.layerSearchText(layer))) {
        return i;
      }
    }
    return -1;
  }
}
