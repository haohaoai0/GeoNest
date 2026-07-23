import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { MaterialStyle } from '@geonest/common';
import { getGisService, GisLoadedLayer, GisService } from '../gis/GisService';
import { GisAttributeValue, GisFeatureSummary, GisGeoProcessResult } from '../model/GeoNestModels';
import {
  createDefaultTopologyRuleSet,
  TopologyIssueReview,
  TopologyRule,
  TopologyRuleSet
} from '../model/TopologyModels';
import { TopologyRuleStore } from '../utils/TopologyRuleStore';

class TopologyIssueItem {
  issueId: string = '';
  featureId: string = '';
  sourceFid: string = '';
  checkName: string = '';
  severity: number = 0;
  message: string = '';
  fieldName: string = '';
  otherFid: string = '';
  fixable: boolean = false;
  repairStrategies: string = '';
  status: string = 'open';
  exception: boolean = false;
  ignoreReason: string = '';

  constructor(featureId: string, issueId: string, sourceFid: string, checkName: string, severity: number,
    message: string, fieldName: string, otherFid: string, fixable: boolean, repairStrategies: string) {
    this.featureId = featureId;
    this.issueId = issueId;
    this.sourceFid = sourceFid;
    this.checkName = checkName;
    this.severity = severity;
    this.message = message;
    this.fieldName = fieldName;
    this.otherFid = otherFid;
    this.fixable = fixable;
    this.repairStrategies = repairStrategies;
  }
}

@Component
export struct TopologyReviewSheet {
  @Prop @Watch('onTrigger') trigger: boolean = false;
  @Prop sourceLayerIndex: number = -1;
  @Prop errorLayerIndex: number = -1;
  @Prop requiredFields: string = '';
  @State private isShow: boolean = false;
  @StorageLink('gnMaterialEnabled') materialEnabled: boolean = true;
  private scroller: Scroller = new Scroller();
  onLocateIssue: (featureId: string, layerIndex: number) => void =
    (_featureId: string, _layerIndex: number): void => {};
  onRepairAndRecheckCompleted: (repairedLayerIndex: number, errorLayerIndex: number, status: string) => void =
    (_repairedLayerIndex: number, _errorLayerIndex: number, _status: string): void => {};
  @State private reviewSourceLayerIndex: number = -1;
  @State private reviewErrorLayerIndex: number = -1;
  @State private reviewRequiredFields: string = '';
  @State private repairRunning: boolean = false;
  @State private runStatus: string = '';
  @State private uiRevision: number = 0;
  @State private rules: TopologyRule[] = [];
  @State private targetLayerIndex: number = -1;
  @State private toleranceText: string = '0.001';
  @State private incrementalOnly: boolean = false;
  @State private previewReady: boolean = false;
  @State private pendingStrategy: string = 'make_valid';
  @State private pendingSourceFids: string[] = [];
  @State private ignoreReason: string = '';
  @State private issueReviews: TopologyIssueReview[] = [];

  onTrigger(): void {
    this.reviewSourceLayerIndex = this.sourceLayerIndex;
    this.reviewErrorLayerIndex = this.errorLayerIndex;
    this.reviewRequiredFields = this.requiredFields;
    this.repairRunning = false;
    this.runStatus = '';
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let store: TopologyRuleStore = new TopologyRuleStore(context);
    let sets: TopologyRuleSet[] = store.loadRuleSets();
    if (sets.length > 0) {
      this.rules = sets[0].rules;
    } else {
      this.rules = createDefaultTopologyRuleSet().rules;
    }
    this.issueReviews = store.loadIssueReviews();
    this.targetLayerIndex = this.reviewSourceLayerIndex;
    this.previewReady = false;
    this.pendingSourceFids = [];
    this.uiRevision++;
    this.isShow = true;
  }

  private sourceLayer(): GisLoadedLayer | undefined {
    return getGisService().getLayer(this.reviewSourceLayerIndex);
  }

  private errorLayer(): GisLoadedLayer | undefined {
    return getGisService().getLayer(this.reviewErrorLayerIndex);
  }

  private attributeText(attribute: GisAttributeValue): string {
    if (attribute.isNull) {
      return '';
    }
    if (attribute.textValue.length > 0) {
      return attribute.textValue;
    }
    return attribute.numberValue.toString();
  }

  private attributeByName(row: GisFeatureSummary, fieldName: string): string {
    for (let i = 0; i < row.attributesPreview.length; i++) {
      let attribute: GisAttributeValue = row.attributesPreview[i];
      if (attribute.name === fieldName) {
        return this.attributeText(attribute);
      }
    }
    return '';
  }

  private buildIssues(): TopologyIssueItem[] {
    let issues: TopologyIssueItem[] = [];
    let layer: GisLoadedLayer | undefined = this.errorLayer();
    if (layer === undefined) {
      return issues;
    }
    for (let i = 0; i < layer.features.length; i++) {
      let row: GisFeatureSummary = layer.features[i];
      let checkName: string = this.attributeByName(row, 'check');
      let severityText: string = this.attributeByName(row, 'severity');
      let severity: number = Number(severityText);
      if (severity !== severity) {
        severity = 0;
      }
      let issueId: string = this.attributeByName(row, 'issue_id');
      if (issueId.length === 0) {
        issueId = 'legacy:' + this.reviewErrorLayerIndex.toString() + ':' + row.featureId;
      }
      let repairStrategies: string = this.attributeByName(row, 'repair');
      let issue: TopologyIssueItem = new TopologyIssueItem(row.featureId, issueId,
        this.attributeByName(row, 'src_fid'), checkName.length > 0 ? checkName : this.attributeByName(row, 'rule_id'),
        severity, this.attributeByName(row, 'message'), this.attributeByName(row, 'field'),
        this.attributeByName(row, 'other_fid'), repairStrategies.length > 0 || checkName === 'invalid_geometry',
        repairStrategies.length > 0 ? repairStrategies : 'make_valid');
      let review: TopologyIssueReview | null = this.reviewByIssueId(issueId);
      if (review !== null) {
        issue.status = review.status;
        issue.exception = review.exception;
        issue.ignoreReason = review.ignoreReason;
      }
      issues.push(issue);
    }
    return issues;
  }

  private reviewByIssueId(issueId: string): TopologyIssueReview | null {
    for (let i = 0; i < this.issueReviews.length; i++) {
      if (this.issueReviews[i].issueId === issueId) {
        return this.issueReviews[i];
      }
    }
    return null;
  }

  private saveIssueReview(issue: TopologyIssueItem, status: string, exception: boolean): void {
    let review: TopologyIssueReview | null = this.reviewByIssueId(issue.issueId);
    if (review === null) {
      review = new TopologyIssueReview(issue.issueId);
      this.issueReviews.push(review);
    }
    review.status = status;
    review.exception = exception;
    review.ignoreReason = this.ignoreReason;
    review.reviewer = 'local_reviewer';
    review.reviewedAt = Date.now();
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let store: TopologyRuleStore = new TopologyRuleStore(context);
    store.saveIssueReviews(this.issueReviews);
    this.issueReviews = this.copyIssueReviews(this.issueReviews);
    this.uiRevision++;
  }

  private copyIssueReviews(source: TopologyIssueReview[]): TopologyIssueReview[] {
    let result: TopologyIssueReview[] = [];
    for (let i = 0; i < source.length; i++) {
      result.push(source[i]);
    }
    return result;
  }

  private fixableIssueCount(): number {
    let count: number = 0;
    let issues: TopologyIssueItem[] = this.buildIssues();
    for (let i = 0; i < issues.length; i++) {
      if (issues[i].fixable) {
        count++;
      }
    }
    return count;
  }

  private severityColor(severity: number): ResourceColor {
    if (severity >= 2) {
      return $r('app.color.gn_red_700');
    }
    if (severity === 1) {
      return $r('app.color.gn_orange_700');
    }
    return $r('app.color.gn_text_muted');
  }

  private severityLabel(severity: number): string {
    if (severity >= 2) {
      return '错误';
    }
    if (severity === 1) {
      return '警告';
    }
    return '提示';
  }

  private sourceLayerName(): string {
    let layer: GisLoadedLayer | undefined = this.sourceLayer();
    if (layer === undefined) {
      return '源图层不可用';
    }
    return layer.info.name;
  }

  private safeOutputName(source: string): string {
    let result: string = '';
    for (let i = 0; i < source.length; i++) {
      let ch: string = source.charAt(i);
      if (ch === '/' || ch === '\\' || ch === ':' || ch === '*' || ch === '?' || ch === '"' ||
        ch === '<' || ch === '>' || ch === '|') {
        result += '_';
      } else {
        result += ch;
      }
    }
    if (result.trim().length === 0) {
      return 'topology_repaired';
    }
    return result.trim();
  }

  private outputDirectory(): string {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let directory: string = getGisService().processingOutputDirectory();
    if (directory.length === 0) {
      directory = context.filesDir + '/geonest_outputs';
    }
    try {
      fs.mkdirSync(directory, true);
    } catch (e) {
    }
    return directory;
  }

  private enabledRulesText(): string {
    let text: string = '';
    for (let i = 0; i < this.rules.length; i++) {
      if (!this.rules[i].enabled) {
        continue;
      }
      if (text.length > 0) {
        text += ';';
      }
      text += this.rules[i].id;
    }
    return text;
  }

  private saveRules(): void {
    let ruleSet: TopologyRuleSet = new TopologyRuleSet('default_topology_rules', '默认拓扑规则集', this.rules);
    let sets: TopologyRuleSet[] = [ruleSet];
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    new TopologyRuleStore(context).saveRuleSets(sets);
  }

  private toggleRule(ruleId: string): void {
    let next: TopologyRule[] = [];
    for (let i = 0; i < this.rules.length; i++) {
      let rule: TopologyRule = this.rules[i];
      if (rule.id === ruleId) {
        rule.enabled = !rule.enabled;
      }
      next.push(rule);
    }
    this.rules = next;
    this.saveRules();
    this.uiRevision++;
  }

  private targetLayerName(): string {
    let layer: GisLoadedLayer | undefined = getGisService().getLayer(this.targetLayerIndex);
    return layer === undefined ? '同源图层' : layer.info.name;
  }

  private cycleTargetLayer(): void {
    let service: GisService = getGisService();
    let count: number = service.getLayerCount();
    if (count === 0) {
      this.targetLayerIndex = this.reviewSourceLayerIndex;
      return;
    }
    let start: number = this.targetLayerIndex;
    for (let offset = 1; offset <= count; offset++) {
      let candidateIndex: number = (start + offset + count) % count;
      let candidate: GisLoadedLayer | undefined = service.getLayer(candidateIndex);
      if (candidate !== undefined && candidate.info.geometryType > 0) {
        this.targetLayerIndex = candidateIndex;
        this.uiRevision++;
        return;
      }
    }
  }

  private selectedDirtyExtentText(): string {
    if (!this.incrementalOnly || this.pendingSourceFids.length === 0) {
      return '';
    }
    let source: GisLoadedLayer | undefined = this.sourceLayer();
    if (source === undefined) {
      return '';
    }
    let found: boolean = false;
    let minX: number = 0;
    let minY: number = 0;
    let maxX: number = 0;
    let maxY: number = 0;
    for (let i = 0; i < source.features.length; i++) {
      let row: GisFeatureSummary = source.features[i];
      if (!this.containsText(this.pendingSourceFids, row.featureId)) {
        continue;
      }
      if (!found) {
        minX = row.envelope.minX;
        minY = row.envelope.minY;
        maxX = row.envelope.maxX;
        maxY = row.envelope.maxY;
        found = true;
      } else {
        minX = Math.min(minX, row.envelope.minX);
        minY = Math.min(minY, row.envelope.minY);
        maxX = Math.max(maxX, row.envelope.maxX);
        maxY = Math.max(maxY, row.envelope.maxY);
      }
    }
    return found ? minX.toString() + ',' + minY.toString() + ',' + maxX.toString() + ',' + maxY.toString() : '';
  }

  private containsText(values: string[], value: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === value) {
        return true;
      }
    }
    return false;
  }

  private parseTolerance(): number {
    let tolerance: number = Number(this.toleranceText);
    if (tolerance !== tolerance || tolerance < 0) {
      return 0;
    }
    return tolerance;
  }

  private runRuleValidation(): void {
    let ruleText: string = this.enabledRulesText();
    if (ruleText.length === 0) {
      this.runStatus = '请至少启用一条拓扑规则';
      return;
    }
    let timestamp: string = Date.now().toString();
    let name: string = this.safeOutputName(this.sourceLayerName() + '_topology_errors');
    let path: string = this.outputDirectory() + '/' + name + '_' + timestamp + '.gpkg';
    this.runStatus = this.incrementalOnly ? '正在验证脏区…' : '正在验证完整数据集…';
    let result: GisGeoProcessResult = getGisService().validateTopologyRules(this.reviewSourceLayerIndex,
      this.targetLayerIndex, ruleText, this.selectedDirtyExtentText(), this.parseTolerance(), path, name);
    if (!result.ok) {
      this.runStatus = '拓扑验证失败：' + result.message;
      return;
    }
    if (result.outputLoaded) {
      this.reviewErrorLayerIndex = getGisService().getActiveLayerIndex();
    }
    this.runStatus = '拓扑验证完成：发现 ' + result.featureCount.toString() + ' 个问题';
    this.uiRevision++;
    this.onRepairAndRecheckCompleted(this.reviewSourceLayerIndex, this.reviewErrorLayerIndex, this.runStatus);
  }

  private chooseIssueForRepair(issue: TopologyIssueItem): void {
    if (issue.sourceFid.length === 0 || issue.sourceFid === '-1') {
      this.runStatus = '该问题没有可直接修复的源要素，需要人工处理';
      return;
    }
    this.pendingSourceFids = [issue.sourceFid];
    let strategies: string[] = issue.repairStrategies.split(';');
    this.pendingStrategy = strategies.length > 0 && strategies[0].length > 0 ? strategies[0] : 'make_valid';
    this.previewReady = false;
    this.runStatus = '已选择修复策略：' + this.pendingStrategy + '，请先生成预览';
  }

  private runRepairPreview(): void {
    if (this.pendingSourceFids.length === 0) {
      this.runStatus = '请先在错误列表选择修复项';
      return;
    }
    let timestamp: string = Date.now().toString();
    let name: string = this.safeOutputName(this.sourceLayerName() + '_repair_preview');
    let path: string = this.outputDirectory() + '/' + name + '_' + timestamp + '.gpkg';
    let result: GisGeoProcessResult = getGisService().repairTopologyIssues(this.reviewSourceLayerIndex,
      this.targetLayerIndex, this.pendingSourceFids, this.pendingStrategy, this.parseTolerance(), true, path, name);
    this.previewReady = result.ok;
    this.runStatus = result.ok ? '修复预览已生成。应用将修改 ' + this.pendingSourceFids.length.toString() +
      ' 个源要素；若与未保存编辑冲突，请取消或回滚。' : '预览失败：' + result.message;
  }

  private applyPreviewedRepair(): void {
    if (!this.previewReady) {
      this.runStatus = '请先生成并检查修复预览';
      return;
    }
    let result: GisGeoProcessResult = getGisService().repairTopologyIssues(this.reviewSourceLayerIndex,
      this.targetLayerIndex, this.pendingSourceFids, this.pendingStrategy, this.parseTolerance(), false, '', '');
    this.runStatus = result.ok ? '修复已写入编辑事务，可提交或回滚：' + result.message : '应用修复失败：' + result.message;
    if (result.ok) {
      this.previewReady = false;
      this.incrementalOnly = true;
      this.uiRevision++;
    }
  }

  private rollbackRepairs(): void {
    let result = getGisService().rollbackEditSession(this.reviewSourceLayerIndex);
    this.previewReady = false;
    this.runStatus = result.ok ? '拓扑修复事务已回滚' : '回滚失败：' + result.message;
    this.uiRevision++;
  }

  private runRepairAndRecheck(): void {
    if (this.repairRunning) {
      return;
    }
    let service: GisService = getGisService();
    if (!service.processingEnvironment().autoLoadOutput) {
      this.runStatus = '一键修复并复检需要自动加载中间结果，请先在设置的“地理处理”中启用自动加载。';
      return;
    }
    let source: GisLoadedLayer | undefined = this.sourceLayer();
    if (source === undefined) {
      this.runStatus = '源图层不可用，无法修复';
      return;
    }
    this.repairRunning = true;
    this.runStatus = '正在生成非破坏性修复副本…';
    let timestamp: string = Date.now().toString();
    let repairedName: string = this.safeOutputName(source.info.name + '_repaired');
    let repairedPath: string = this.outputDirectory() + '/' + repairedName + '_' + timestamp + '.shp';
    let repairResult: GisGeoProcessResult = service.runRepair(this.reviewSourceLayerIndex, repairedPath, repairedName);
    if (!repairResult.ok) {
      this.repairRunning = false;
      this.runStatus = '修复失败：' + repairResult.message;
      return;
    }
    if (!repairResult.outputLoaded) {
      this.repairRunning = false;
      this.runStatus = '修复副本已生成，但未能加载中间结果：' + repairResult.message;
      this.onRepairAndRecheckCompleted(-1, -1, this.runStatus);
      return;
    }

    let repairedLayerIndex: number = service.getActiveLayerIndex();
    let recheckName: string = this.safeOutputName(repairedName + '_quality_errors');
    let recheckPath: string = this.outputDirectory() + '/' + recheckName + '_' + timestamp + '.shp';
    let qualityResult: GisGeoProcessResult = service.runQualityCheck(repairedLayerIndex, this.reviewRequiredFields,
      recheckPath, recheckName);
    if (!qualityResult.ok) {
      this.repairRunning = false;
      this.runStatus = '修复副本已生成，但复检失败：' + qualityResult.message;
      this.onRepairAndRecheckCompleted(repairedLayerIndex, -1, this.runStatus);
      return;
    }
    if (!qualityResult.outputLoaded) {
      this.repairRunning = false;
      this.runStatus = '修复和复检成果已生成，但错误图层未能加载：' + qualityResult.message;
      this.onRepairAndRecheckCompleted(repairedLayerIndex, -1, this.runStatus);
      return;
    }

    this.reviewSourceLayerIndex = repairedLayerIndex;
    this.reviewErrorLayerIndex = service.getActiveLayerIndex();
    this.repairRunning = false;
    this.runStatus = '修复和复检完成：剩余错误 ' + qualityResult.featureCount.toString() + ' 条';
    this.uiRevision++;
    this.onRepairAndRecheckCompleted(this.reviewSourceLayerIndex, this.reviewErrorLayerIndex, this.runStatus);
  }

  @Builder
  topologyRulePanel() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text($r('app.string.gn_topology_rule_set'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
          .layoutWeight(1)
        Button(this.targetLayerName(), { type: ButtonType.Capsule, stateEffect: true })
          .height(28)
          .fontSize(11)
          .fontColor($r('app.color.gn_blue_800'))
          .backgroundColor($r('app.color.gn_blue_100'))
          .onClick(() => {
            this.cycleTargetLayer();
          })
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.rules, (rule: TopologyRule) => {
          Text((rule.enabled ? '✓ ' : '') + rule.name)
            .height(28)
            .fontSize(11)
            .fontColor(rule.enabled ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
            .backgroundColor(rule.enabled ? $r('app.color.gn_blue_100') : $r('app.color.gn_pane'))
            .borderRadius(4)
            .padding({ left: 8, right: 8 })
            .margin({ right: 6, bottom: 6 })
            .onClick(() => {
              this.toggleRule(rule.id);
            })
        }, (rule: TopologyRule) => 'topology-rule:' + rule.id)
      }
      Row({ space: 8 }) {
        TextInput({ text: this.toleranceText, placeholder: $r('app.string.gn_topology_tolerance') })
          .height(30)
          .fontSize(11)
          .layoutWeight(1)
          .backgroundColor($r('app.color.gn_pane'))
          .onChange((value: string) => {
            this.toleranceText = value;
          })
        Button(this.incrementalOnly ? $r('app.string.gn_topology_incremental') :
          $r('app.string.gn_topology_full_validation'), { type: ButtonType.Capsule, stateEffect: true })
          .height(30)
          .fontSize(11)
          .fontColor($r('app.color.gn_blue_800'))
          .backgroundColor($r('app.color.gn_blue_100'))
          .onClick(() => {
            this.incrementalOnly = !this.incrementalOnly;
          })
        Button($r('app.string.gn_topology_validate'), { type: ButtonType.Capsule, stateEffect: true })
          .height(30)
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.gn_blue_800'))
          .onClick(() => {
            this.runRuleValidation();
          })
      }
    }
    .padding(12)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  repairTransactionPanel() {
    Column({ space: 8 }) {
      Text($r('app.string.gn_topology_repair_transaction'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_primary'))
        .width('100%')
      Text(this.pendingSourceFids.length === 0 ? $r('app.string.gn_topology_select_issue_repair') :
        '策略 ' + this.pendingStrategy + ' · ' + this.pendingSourceFids.length.toString() + ' 个要素')
        .fontSize(11)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')
      TextInput({ text: this.ignoreReason, placeholder: $r('app.string.gn_topology_ignore_reason') })
        .height(30)
        .fontSize(11)
        .backgroundColor($r('app.color.gn_pane'))
        .onChange((value: string) => {
          this.ignoreReason = value;
        })
      Row({ space: 8 }) {
        Button($r('app.string.gn_topology_preview_repair'), { type: ButtonType.Capsule, stateEffect: true })
          .height(30)
          .fontSize(11)
          .enabled(this.pendingSourceFids.length > 0)
          .onClick(() => {
            this.runRepairPreview();
          })
        Button($r('app.string.gn_topology_apply_repair'), { type: ButtonType.Capsule, stateEffect: true })
          .height(30)
          .fontSize(11)
          .enabled(this.previewReady)
          .fontColor(Color.White)
          .backgroundColor(this.previewReady ? $r('app.color.gn_orange_700') : $r('app.color.gn_text_muted'))
          .onClick(() => {
            this.applyPreviewedRepair();
          })
        Button($r('app.string.gn_topology_rollback'), { type: ButtonType.Capsule, stateEffect: true })
          .height(30)
          .fontSize(11)
          .fontColor($r('app.color.gn_red_700'))
          .onClick(() => {
            this.rollbackRepairs();
          })
      }
    }
    .padding(12)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  summaryPanel() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.list_checkmark'))
          .fontSize(22)
          .fontColor([$r('app.color.gn_blue_800')])
        Column({ space: 3 }) {
          Text(this.sourceLayerName())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.buildIssues().length.toString() + ' 条已载入错误 · ' +
            this.fixableIssueCount().toString() + ' 条无效几何')
            .fontSize(12)
            .fontColor($r('app.color.gn_text_muted'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Text($r('app.string.gn_topology_review_desc'))
        .fontSize(12)
        .fontColor($r('app.color.gn_text_muted'))
        .width('100%')

      Text($r('app.string.gn_topology_repair_scope'))
        .fontSize(11)
        .fontColor($r('app.color.gn_orange_700'))
        .width('100%')
        .padding(10)
        .borderRadius(6)
        .backgroundColor($r('app.color.gn_pane_alt'))

      Button($r('app.string.gn_topology_repair_recheck'), { type: ButtonType.Capsule, stateEffect: true })
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.fixableIssueCount() > 0 && !this.repairRunning ?
          $r('app.color.gn_blue_800') : $r('app.color.gn_text_muted'))
        .enabled(this.fixableIssueCount() > 0 && !this.repairRunning)
        .onClick(() => {
          this.runRepairAndRecheck();
        })

      if (this.runStatus.length > 0) {
        Text(this.runStatus)
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
      }
    }
    .padding(14)
    .borderRadius(6)
    .backgroundColor($r('app.color.gn_paper'))
    .border({ width: 1, color: $r('app.color.gn_line') })
  }

  @Builder
  issueMeta(label: ResourceStr, value: string) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor($r('app.color.gn_text_muted'))
      Text(value.length > 0 ? value : '-')
        .fontSize(10)
        .fontColor($r('app.color.gn_text_primary'))
    }
  }

  @Builder
  issueRow(issue: TopologyIssueItem) {
    ListItem() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(this.severityLabel(issue.severity))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.severityColor(issue.severity))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .backgroundColor($r('app.color.gn_pane_alt'))
          Text(issue.checkName.length > 0 ? issue.checkName : 'quality_issue')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.gn_text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(issue.fixable ? $r('app.string.gn_topology_issue_fixable') :
            $r('app.string.gn_topology_issue_manual'))
            .fontSize(10)
            .fontColor(issue.fixable ? $r('app.color.gn_green_700') : $r('app.color.gn_text_muted'))
          Text(issue.exception ? $r('app.string.gn_topology_exception') : issue.status)
            .fontSize(10)
            .fontColor(issue.status === 'resolved' ? $r('app.color.gn_green_700') :
              $r('app.color.gn_orange_700'))
        }
        .width('100%')

        Text(issue.message.length > 0 ? issue.message : 'Topology quality issue')
          .fontSize(12)
          .fontColor($r('app.color.gn_text_muted'))
          .width('100%')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 12 }) {
          this.issueMeta($r('app.string.gn_topology_issue_source'), issue.sourceFid)
          if (issue.otherFid.length > 0 && issue.otherFid !== '-1') {
            this.issueMeta($r('app.string.gn_topology_issue_related'), issue.otherFid)
          }
          if (issue.fieldName.length > 0) {
            Text(issue.fieldName)
              .fontSize(10)
              .fontColor($r('app.color.gn_blue_800'))
          }
          Blank()
          Button($r('app.string.gn_topology_locate_issue'), { type: ButtonType.Capsule, stateEffect: true })
            .height(28)
            .fontSize(11)
            .fontColor($r('app.color.gn_blue_800'))
            .backgroundColor($r('app.color.gn_blue_100'))
            .onClick(() => {
              this.onLocateIssue(issue.featureId, this.reviewErrorLayerIndex);
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          if (issue.fixable) {
            Button($r('app.string.gn_topology_choose_repair'), { type: ButtonType.Capsule, stateEffect: true })
              .height(26)
              .fontSize(10)
              .onClick(() => {
                this.chooseIssueForRepair(issue);
              })
          }
          Button($r('app.string.gn_topology_mark_resolved'), { type: ButtonType.Capsule, stateEffect: true })
            .height(26)
            .fontSize(10)
            .onClick(() => {
              this.saveIssueReview(issue, 'resolved', false);
            })
          Button($r('app.string.gn_topology_ignore_issue'), { type: ButtonType.Capsule, stateEffect: true })
            .height(26)
            .fontSize(10)
            .onClick(() => {
              this.saveIssueReview(issue, 'ignored', true);
            })
          Blank()
          if (issue.ignoreReason.length > 0) {
            Text(issue.ignoreReason)
              .fontSize(10)
              .fontColor($r('app.color.gn_text_muted'))
              .maxLines(1)
          }
        }
        .width('100%')
      }
      .padding(12)
      .borderRadius(6)
      .backgroundColor($r('app.color.gn_paper'))
      .border({ width: 1, color: $r('app.color.gn_line') })
    }
  }

  @Builder
  sheetContent() {
    Column() {
      HdsNavigation() {
        Column() {
          Scroll(this.scroller) {
            Column({ space: 12 }) {
              Blank().height(80).width('100%')
              Text(this.uiRevision.toString())
                .width(0)
                .height(0)
                .fontSize(0)
                .opacity(0)
              this.summaryPanel()
              this.topologyRulePanel()
              this.repairTransactionPanel()
              Text($r('app.string.gn_topology_preview_limit'))
                .fontSize(11)
                .fontColor($r('app.color.gn_text_muted'))
                .width('100%')
            }
            .padding(14)
          }
          .height(430)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          Column() {
            Text($r('app.string.gn_topology_issue_list'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.gn_text_primary'))
              .width('100%')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            if (this.buildIssues().length === 0) {
              Column({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.checkmark_circle'))
                  .fontSize(30)
                  .fontColor([$r('app.color.gn_green_700')])
                Text($r('app.string.gn_topology_empty'))
                  .fontSize(13)
                  .fontColor($r('app.color.gn_text_muted'))
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              List({ space: 8 }) {
                ForEach(this.buildIssues(), (issue: TopologyIssueItem) => {
                  this.issueRow(issue)
                }, (issue: TopologyIssueItem) => 'topology:' + this.reviewErrorLayerIndex.toString() + ':' +
                  issue.featureId)
              }
              .layoutWeight(1)
              .scrollBar(BarState.Auto)
              .padding({ left: 14, right: 14, bottom: 14 })
            }
          }
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
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
          title: { mainTitle: $r('app.string.gn_topology_review_title') },
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
    .width('100%')
    .height('100%')
  }

  build() {
    Row().width(0).height(0)
      .bindSheet($$this.isShow, this.sheetContent(), {
        width: 900,
        height: 720,
        detents: [720],
        preferType: SheetType.CENTER,
        dragBar: false,
        backgroundColor: Color.Transparent,
        blurStyle: BlurStyle.Regular,
        showClose: false,
        onDisappear: (): void => { this.isShow = false; }
      })
  }
}
