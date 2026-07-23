export class ImportedDataFile {
  uri: string = '';
  fileName: string = '';
  displayName: string = '';
  extension: string = '';
  destinationPath: string = '';
  destinationDir: string = '';
  baseName: string = '';
  displayBaseName: string = '';

  constructor(uri: string, fileName: string, displayName: string, extension: string, destinationPath: string,
    destinationDir: string, baseName: string, displayBaseName: string) {
    this.uri = uri;
    this.fileName = fileName;
    this.displayName = displayName;
    this.extension = extension;
    this.destinationPath = destinationPath;
    this.destinationDir = destinationDir;
    this.baseName = baseName;
    this.displayBaseName = displayBaseName;
  }
}

export class ClipboardCoordinateCandidate {
  found: boolean = false;
  x: number = 0;
  y: number = 0;

  constructor(found: boolean, x: number, y: number) {
    this.found = found;
    this.x = x;
    this.y = y;
  }
}

export class GlobalSearchCandidate {
  kind: number = 0;
  key: string = '';
  title: string = '';
  subtitle: string = '';
  category: string = '';
  sourceText: string = '';
  actionId: number = 0;
  layerIndex: number = -1;
  geometryType: number = 0;
  featureCount: number = 0;
  crs: string = '';
}

export class LayerDisplayItem {
  index: number = 0;
  id: string = '';
  name: string = '';
  geomType: number = 0;
  visible: boolean = true;
  featureCount: number = 0;
  fieldCount: number = 0;
  crs: string = '';
  symbolColor: string = '#1D4F91';
  sourcePath: string = '';
  sourceDisplayText: string = '';
  referenceText: string = '';
  geometryText: string = '';
  rendererText: string = '';
  labelText: string = '';
  fieldText: string = '';
  selectedFeatureCount: number = 0;
  activeEdit: boolean = false;
  stateKey: string = '';
}

export class RecentProjectRecord {
  uri: string = '';
  name: string = '';
  owner: string = '';
  crs: string = '';
  workspaceName: string = '';

  constructor(uri: string, name: string, owner: string, crs: string, workspaceName: string) {
    this.uri = uri;
    this.name = name;
    this.owner = owner;
    this.crs = crs;
    this.workspaceName = workspaceName;
  }
}

export class WorkbenchFieldItem {
  name: string = '';
  alias: string = '';
  typeName: string = '';

  constructor(name: string, alias: string, typeName: string) {
    this.name = name;
    this.alias = alias;
    this.typeName = typeName;
  }
}
