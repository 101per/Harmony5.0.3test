interface TabItem {
  name: string;
  iconSelected?: Resource;
  iconUnselected?: Resource;
}

@Component
export struct BottomTabBar {
  @Link currentIndex: number;

  private tabs: TabItem[] = [
    {
      name: "首页",
      iconSelected: $r('app.media.home_select'),
      iconUnselected: $r('app.media.home_unselect')
    },
    {
      name: "控制",
      iconSelected: $r('app.media.control_select'),
      iconUnselected: $r('app.media.control_unselect')
    },
    {
      name: "处理",
      iconSelected: $r('app.media.deal_select'),
      iconUnselected: $r('app.media.deal_unselect')
    },
    {
      name: "传输",
      iconSelected: $r('app.media.trans_select'),
      iconUnselected: $r('app.media.trans_unselect')
    }
  ];

  build() {
    Row() {
      ForEach(this.tabs, (item: TabItem, index: number) => {
        Column() {
          if (item.iconSelected && item.iconUnselected) {
            Image(this.currentIndex === index ? item.iconSelected : item.iconUnselected)
              .width(24)
              .height(24)
              .scale({ x: this.currentIndex === index ? 1.2 : 1.0, y: this.currentIndex === index ? 1.2 : 1.0 })
              .animation({ duration: 200 })
          } else {
            Text(item.name)
              .fontSize(this.currentIndex === index ? 24 : 20)
              .scale({ x: this.currentIndex === index ? 1.2 : 1.0, y: this.currentIndex === index ? 1.2 : 1.0 })
              .animation({ duration: 200 })
          }

          Text(item.name)
            .fontColor(this.currentIndex === index ? '#007DFF' : '#999999')
            .fontSize(12)
        }
        .onClick(() => {
          this.currentIndex = index;
        })
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }, (item: TabItem) => item.name)
    }
    .height(56)
    .backgroundColor('#FFFFFF')
    .border({ 
      width: { top: 1 },
      color: '#EEEEEE',
      style: BorderStyle.Solid
    })
  }
}