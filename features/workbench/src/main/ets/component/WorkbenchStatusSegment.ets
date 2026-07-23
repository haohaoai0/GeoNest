@Component
export struct WorkbenchStatusSegment {
  @Prop icon: Resource;
  @Prop label: ResourceStr;
  @Prop color: ResourceColor;
  @Prop radiusValue: number = 6;

  build() {
    Row({ space: 4 }) {
      SymbolGlyph(this.icon)
        .fontSize(13)
        .fontColor([this.color])
      Text(this.label)
        .fontSize(12)
        .fontColor(this.color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(24)
    .padding({ left: 7, right: 7 })
    .borderRadius(this.radiusValue)
    .backgroundColor($r('app.color.gn_pane_alt'))
  }
}
