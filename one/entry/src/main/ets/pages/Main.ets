import { BottomTabBar } from '../components/BottomTabBar';
import { Control } from './control';
import { Deal } from './deal';
import { Home } from './home';
import { Trans } from './trans';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  build() {
    Column() {
      // 页面内容区域
      Stack() {
        // 首页内容
        if (this.currentIndex === 0) {
          Home()
        }
        // 控制页面
        if (this.currentIndex === 1) {
          Control()
        }
        // 处理页面
        if (this.currentIndex === 2) {
          RelativeContainer() {
            Deal()
          }
        }
        // 传输页面
        if (this.currentIndex === 3) {
          Trans()
        }
      }
      .layoutWeight(1)

      // 底部标签栏
      BottomTabBar({ currentIndex: $currentIndex })
    }
    .height('100%')
    .width('100%')
  }
}