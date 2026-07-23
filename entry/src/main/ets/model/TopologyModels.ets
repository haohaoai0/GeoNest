export const TOPOLOGY_RULE_POLYGON_NO_OVERLAP: string = 'polygon_no_overlap';
export const TOPOLOGY_RULE_POLYGON_NO_GAPS: string = 'polygon_no_gaps';
export const TOPOLOGY_RULE_MUST_BE_COVERED_BY: string = 'must_be_covered_by';
export const TOPOLOGY_RULE_LINE_NO_INTERSECTION: string = 'line_no_intersection';
export const TOPOLOGY_RULE_LINE_NO_SELF_INTERSECTION: string = 'line_no_self_intersection';
export const TOPOLOGY_RULE_LINE_NO_DANGLES: string = 'line_no_dangles';
export const TOPOLOGY_RULE_POINT_ON_LINE: string = 'point_on_line';
export const TOPOLOGY_RULE_POINT_ON_ENDPOINT: string = 'point_on_endpoint';
export const TOPOLOGY_RULE_POINT_IN_POLYGON: string = 'point_in_polygon';

export const TOPOLOGY_REPAIR_MAKE_VALID: string = 'make_valid';
export const TOPOLOGY_REPAIR_SPLIT: string = 'split';
export const TOPOLOGY_REPAIR_SNAP: string = 'snap';
export const TOPOLOGY_REPAIR_MERGE: string = 'merge';
export const TOPOLOGY_REPAIR_EXTEND: string = 'extend';
export const TOPOLOGY_REPAIR_TRIM: string = 'trim';
export const TOPOLOGY_REPAIR_CLIP: string = 'clip';

export class TopologyRule {
  id: string = '';
  name: string = '';
  sourceGeometryType: number = 0;
  targetGeometryType: number = 0;
  sourceLayerId: string = '';
  targetLayerId: string = '';
  tolerance: number = 0;
  enabled: boolean = true;
  repairStrategies: string = '';

  constructor(id: string, name: string, sourceGeometryType: number, targetGeometryType: number,
    repairStrategies: string) {
    this.id = id;
    this.name = name;
    this.sourceGeometryType = sourceGeometryType;
    this.targetGeometryType = targetGeometryType;
    this.repairStrategies = repairStrategies;
  }
}

export class TopologyRuleSet {
  id: string = '';
  name: string = '';
  enabled: boolean = true;
  updatedAt: number = 0;
  rules: TopologyRule[] = [];

  constructor(id: string, name: string, rules: TopologyRule[]) {
    this.id = id;
    this.name = name;
    this.rules = rules;
    this.updatedAt = Date.now();
  }

  enabledRuleIds(): string {
    let result: string = '';
    for (let i = 0; i < this.rules.length; i++) {
      if (!this.rules[i].enabled) {
        continue;
      }
      if (result.length > 0) {
        result += ';';
      }
      result += this.rules[i].id;
    }
    return result;
  }
}

export class TopologyDirtyArea {
  minX: number = 0;
  minY: number = 0;
  maxX: number = 0;
  maxY: number = 0;
  valid: boolean = false;

  constructor(minX: number, minY: number, maxX: number, maxY: number, valid: boolean) {
    this.minX = minX;
    this.minY = minY;
    this.maxX = maxX;
    this.maxY = maxY;
    this.valid = valid;
  }

  toNativeText(): string {
    if (!this.valid) {
      return '';
    }
    return this.minX.toString() + ',' + this.minY.toString() + ',' + this.maxX.toString() + ',' +
      this.maxY.toString();
  }
}

export class TopologyIssueReview {
  issueId: string = '';
  status: string = 'open';
  exception: boolean = false;
  ignoreReason: string = '';
  reviewer: string = '';
  reviewedAt: number = 0;

  constructor(issueId: string) {
    this.issueId = issueId;
  }
}

export class SnappingConfiguration {
  enabled: boolean = true;
  pixelTolerance: number = 8;
  vertexPriority: number = 1;
  segmentPriority: number = 2;
  endpointPriority: number = 0;
  crossLayer: boolean = true;
  spatialIndexEnabled: boolean = true;

  nativeTolerance(mapUnitsPerPixel: number): number {
    let pixels: number = this.pixelTolerance > 0 ? this.pixelTolerance : 8;
    let mapUnits: number = mapUnitsPerPixel > 0 ? mapUnitsPerPixel : 1;
    return pixels * mapUnits;
  }
}

export function createDefaultTopologyRuleSet(): TopologyRuleSet {
  let rules: TopologyRule[] = [];
  rules.push(new TopologyRule(TOPOLOGY_RULE_POLYGON_NO_OVERLAP, '面不得重叠', 3, 3, 'clip;merge'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_POLYGON_NO_GAPS, '面不得有缝隙', 3, 3, 'extend;merge'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_MUST_BE_COVERED_BY, '必须被覆盖', 0, 3, 'snap;clip'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_LINE_NO_INTERSECTION, '线不得相交', 2, 2, 'split;trim'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_LINE_NO_SELF_INTERSECTION, '线不得自相交', 2, 2,
    'split;make_valid'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_LINE_NO_DANGLES, '线不得有悬挂端点', 2, 2, 'snap;extend;trim'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_POINT_ON_LINE, '点必须在线上', 1, 2, 'snap'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_POINT_ON_ENDPOINT, '点必须在端点上', 1, 2, 'snap'));
  rules.push(new TopologyRule(TOPOLOGY_RULE_POINT_IN_POLYGON, '点必须在面内', 1, 3, 'snap'));
  return new TopologyRuleSet('default_topology_rules', '默认拓扑规则集', rules);
}
