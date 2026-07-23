import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  createDefaultTopologyRuleSet,
  SnappingConfiguration,
  TopologyIssueReview,
  TopologyRule,
  TopologyRuleSet
} from '../model/TopologyModels';

const TOPOLOGY_STORE: string = 'geonest_topology';
const RULE_SETS_KEY: string = 'rule_sets_v1';
const ISSUE_REVIEWS_KEY: string = 'issue_reviews_v1';
const SNAP_ENABLED_KEY: string = 'snap_enabled';
const SNAP_PIXEL_TOLERANCE_KEY: string = 'snap_pixel_tolerance';
const SNAP_VERTEX_PRIORITY_KEY: string = 'snap_vertex_priority';
const SNAP_SEGMENT_PRIORITY_KEY: string = 'snap_segment_priority';
const SNAP_ENDPOINT_PRIORITY_KEY: string = 'snap_endpoint_priority';
const SNAP_CROSS_LAYER_KEY: string = 'snap_cross_layer';
const SNAP_SPATIAL_INDEX_KEY: string = 'snap_spatial_index';

function escapeField(value: string): string {
  let result: string = '';
  for (let i = 0; i < value.length; i++) {
    let ch: string = value.charAt(i);
    if (ch === '%') {
      result += '%25';
    } else if (ch === '|') {
      result += '%7C';
    } else if (ch === '\n') {
      result += '%0A';
    } else if (ch === '\r') {
      result += '%0D';
    } else {
      result += ch;
    }
  }
  return result;
}

function unescapeField(value: string): string {
  let result: string = '';
  let i: number = 0;
  while (i < value.length) {
    if (value.charAt(i) === '%' && i + 2 < value.length) {
      let code: string = value.substring(i, i + 3);
      if (code === '%25') {
        result += '%';
        i += 3;
        continue;
      }
      if (code === '%7C') {
        result += '|';
        i += 3;
        continue;
      }
      if (code === '%0A') {
        result += '\n';
        i += 3;
        continue;
      }
      if (code === '%0D') {
        result += '\r';
        i += 3;
        continue;
      }
    }
    result += value.charAt(i);
    i++;
  }
  return result;
}

function splitRecord(line: string): string[] {
  return line.split('|');
}

function boolText(value: boolean): string {
  return value ? '1' : '0';
}

export class TopologyRuleStore {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  loadRuleSets(): TopologyRuleSet[] {
    let result: TopologyRuleSet[] = [];
    try {
      let prefs: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: TOPOLOGY_STORE });
      let text: string = prefs.getSync(RULE_SETS_KEY, '') as string;
      let lines: string[] = text.split('\n');
      let current: TopologyRuleSet | null = null;
      for (let i = 0; i < lines.length; i++) {
        let fields: string[] = splitRecord(lines[i]);
        if (fields.length >= 5 && fields[0] === 'SET') {
          current = new TopologyRuleSet(unescapeField(fields[1]), unescapeField(fields[2]), []);
          current.enabled = fields[3] === '1';
          current.updatedAt = Number(fields[4]);
          result.push(current);
        } else if (fields.length >= 10 && fields[0] === 'RULE' && current !== null) {
          let rule: TopologyRule = new TopologyRule(unescapeField(fields[1]), unescapeField(fields[2]),
            Number(fields[3]), Number(fields[4]), unescapeField(fields[9]));
          rule.sourceLayerId = unescapeField(fields[5]);
          rule.targetLayerId = unescapeField(fields[6]);
          rule.tolerance = Number(fields[7]);
          rule.enabled = fields[8] === '1';
          current.rules.push(rule);
        }
      }
    } catch (e) {
      result = [];
    }
    if (result.length === 0) {
      result.push(createDefaultTopologyRuleSet());
      this.saveRuleSets(result);
    }
    return result;
  }

  saveRuleSets(ruleSets: TopologyRuleSet[]): boolean {
    let lines: string[] = [];
    for (let i = 0; i < ruleSets.length; i++) {
      let ruleSet: TopologyRuleSet = ruleSets[i];
      ruleSet.updatedAt = Date.now();
      lines.push('SET|' + escapeField(ruleSet.id) + '|' + escapeField(ruleSet.name) + '|' +
        boolText(ruleSet.enabled) + '|' + ruleSet.updatedAt.toString());
      for (let j = 0; j < ruleSet.rules.length; j++) {
        let rule: TopologyRule = ruleSet.rules[j];
        lines.push('RULE|' + escapeField(rule.id) + '|' + escapeField(rule.name) + '|' +
          rule.sourceGeometryType.toString() + '|' + rule.targetGeometryType.toString() + '|' +
          escapeField(rule.sourceLayerId) + '|' + escapeField(rule.targetLayerId) + '|' +
          rule.tolerance.toString() + '|' + boolText(rule.enabled) + '|' + escapeField(rule.repairStrategies));
      }
    }
    try {
      let prefs: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: TOPOLOGY_STORE });
      prefs.putSync(RULE_SETS_KEY, lines.join('\n'));
      prefs.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  loadIssueReviews(): TopologyIssueReview[] {
    let reviews: TopologyIssueReview[] = [];
    try {
      let prefs: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: TOPOLOGY_STORE });
      let text: string = prefs.getSync(ISSUE_REVIEWS_KEY, '') as string;
      let lines: string[] = text.split('\n');
      for (let i = 0; i < lines.length; i++) {
        let fields: string[] = splitRecord(lines[i]);
        if (fields.length < 7 || fields[0] !== 'REVIEW') {
          continue;
        }
        let review: TopologyIssueReview = new TopologyIssueReview(unescapeField(fields[1]));
        review.status = unescapeField(fields[2]);
        review.exception = fields[3] === '1';
        review.ignoreReason = unescapeField(fields[4]);
        review.reviewer = unescapeField(fields[5]);
        review.reviewedAt = Number(fields[6]);
        reviews.push(review);
      }
    } catch (e) {
      reviews = [];
    }
    return reviews;
  }

  saveIssueReviews(reviews: TopologyIssueReview[]): boolean {
    let lines: string[] = [];
    for (let i = 0; i < reviews.length; i++) {
      let review: TopologyIssueReview = reviews[i];
      lines.push('REVIEW|' + escapeField(review.issueId) + '|' + escapeField(review.status) + '|' +
        boolText(review.exception) + '|' + escapeField(review.ignoreReason) + '|' +
        escapeField(review.reviewer) + '|' + review.reviewedAt.toString());
    }
    try {
      let prefs: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: TOPOLOGY_STORE });
      prefs.putSync(ISSUE_REVIEWS_KEY, lines.join('\n'));
      prefs.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  loadSnappingConfiguration(): SnappingConfiguration {
    let config: SnappingConfiguration = new SnappingConfiguration();
    try {
      let prefs: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: TOPOLOGY_STORE });
      config.enabled = prefs.getSync(SNAP_ENABLED_KEY, true) as boolean;
      config.pixelTolerance = prefs.getSync(SNAP_PIXEL_TOLERANCE_KEY, 8) as number;
      config.vertexPriority = prefs.getSync(SNAP_VERTEX_PRIORITY_KEY, 1) as number;
      config.segmentPriority = prefs.getSync(SNAP_SEGMENT_PRIORITY_KEY, 2) as number;
      config.endpointPriority = prefs.getSync(SNAP_ENDPOINT_PRIORITY_KEY, 0) as number;
      config.crossLayer = prefs.getSync(SNAP_CROSS_LAYER_KEY, true) as boolean;
      config.spatialIndexEnabled = prefs.getSync(SNAP_SPATIAL_INDEX_KEY, true) as boolean;
    } catch (e) {
    }
    return config;
  }

  saveSnappingConfiguration(config: SnappingConfiguration): boolean {
    try {
      let prefs: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: TOPOLOGY_STORE });
      prefs.putSync(SNAP_ENABLED_KEY, config.enabled);
      prefs.putSync(SNAP_PIXEL_TOLERANCE_KEY, config.pixelTolerance);
      prefs.putSync(SNAP_VERTEX_PRIORITY_KEY, config.vertexPriority);
      prefs.putSync(SNAP_SEGMENT_PRIORITY_KEY, config.segmentPriority);
      prefs.putSync(SNAP_ENDPOINT_PRIORITY_KEY, config.endpointPriority);
      prefs.putSync(SNAP_CROSS_LAYER_KEY, config.crossLayer);
      prefs.putSync(SNAP_SPATIAL_INDEX_KEY, config.spatialIndexEnabled);
      prefs.flush();
      return true;
    } catch (e) {
      return false;
    }
  }
}
