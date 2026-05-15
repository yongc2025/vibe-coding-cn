---
name: uniapp
description: UniApp 跨平台小程序/APP 开发技能。覆盖 UniApp 框架、Vue3+TypeScript、uni-ui 组件库、条件编译、多端发布（微信/支付宝/百度/字节/QQ 小程序 + H5 + APP）、页面生命周期、组件通信、API 调用、多端适配策略及性能优化。
---

# UniApp 小程序开发

## When to Use This Skill

- 用户需要一套代码发布到多个小程序平台（微信/支付宝/百度/字节/QQ）+ H5 + APP
- 使用 UniApp 框架（Vue3 + TypeScript 或 Vue2 + JavaScript）进行开发
- 涉及页面开发、组件通信、状态管理、网络请求、本地存储等
- 需要使用 uni-ui 或其他 UI 组件库
- 需要条件编译处理多端差异
- 需要优化小程序性能（分包加载、渲染优化、体积控制）

## Not For / Boundaries

- **不适用于**纯微信小程序原生开发（使用 wechat-mp 技能）
- **不适用于**纯 Web 前端开发（使用 Vue/React 技能）
- **不适用于**深度原生 APP 开发（需要原生插件时可用 UniApp 原生插件）
- **不涵盖**UniApp 云开发（uniCloud）的完整教程（可参考官方文档）
- 对于只需要微信小程序的场景，原生开发可能更轻量

## Quick Reference

### 1. 项目初始化

```bash
# 使用 Vue3 + TypeScript + Vite
npx degit dcloudio/uni-preset-vue#vite-ts my-app
cd my-app
npm install
npm run dev:mp-weixin     # 微信小程序
npm run dev:mp-alipay     # 支付宝小程序
npm run dev:h5            # H5
npm run dev:app           # APP

# 使用 HBuilderX（可视化 IDE）
# 1. 下载 HBuilderX → https://www.dcloud.io/hbuilderx.html
# 2. 新建项目 → 选择 UniApp → Vue3 模板
# 3. 运行 → 运行到小程序模拟器
```

### 2. 项目结构

```
src/
├── pages/                   # 页面
│   ├── index/
│   │   └── index.vue        # 首页
│   ├── login/
│   │   └── index.vue
│   └── product/
│       └── detail.vue
├── pages-sub/               # 分包页面
│   ├── order/
│   │   ├── list.vue
│   │   └── detail.vue
│   └── settings/
│       └── index.vue
├── components/              # 公共组件
│   ├── NavBar.vue
│   ├── ProductCard.vue
│   └── EmptyState.vue
├── store/                   # Pinia 状态管理
│   ├── index.ts
│   ├── user.ts
│   └── cart.ts
├── api/                     # API 接口
│   ├── request.ts
│   ├── user.ts
│   └── product.ts
├── utils/                   # 工具函数
│   ├── storage.ts
│   ├── format.ts
│   └── platform.ts
├── static/                  # 静态资源
│   ├── images/
│   └── fonts/
├── uni_modules/             # uni_modules 插件
├── pages.json               # 页面路由配置
├── manifest.json            # 应用配置
├── uni.scss                 # 全局样式变量
├── App.vue                  # 应用入口
└── main.ts                  # 入口文件
```

### 3. 页面配置 — pages.json

```json
{
  "pages": [
    { "path": "pages/index/index", "style": { "navigationBarTitleText": "首页" } },
    { "path": "pages/login/index", "style": { "navigationBarTitleText": "登录" } },
    { "path": "pages/product/detail", "style": { "navigationBarTitleText": "商品详情" } }
  ],
  "subPackages": [
    {
      "root": "pages-sub/order",
      "pages": [
        { "path": "list", "style": { "navigationBarTitleText": "订单列表" } },
        { "path": "detail", "style": { "navigationBarTitleText": "订单详情" } }
      ]
    },
    {
      "root": "pages-sub/settings",
      "pages": [
        { "path": "index", "style": { "navigationBarTitleText": "设置" } }
      ]
    }
  ],
  "tabBar": {
    "color": "#999",
    "selectedColor": "#007AFF",
    "borderStyle": "black",
    "list": [
      { "pagePath": "pages/index/index", "text": "首页", "iconPath": "static/tab/home.png", "selectedIconPath": "static/tab/home-active.png" },
      { "pagePath": "pages/login/index", "text": "我的", "iconPath": "static/tab/user.png", "selectedIconPath": "static/tab/user-active.png" }
    ]
  },
  "globalStyle": {
    "navigationBarTextStyle": "black",
    "navigationBarTitleText": "My App",
    "navigationBarBackgroundColor": "#ffffff",
    "backgroundColor": "#f5f5f5"
  }
}
```

### 4. 页面开发 — Vue3 + TypeScript

```vue
<!-- pages/index/index.vue -->
<template>
  <view class="container">
    <!-- 条件编译：仅微信小程序 -->
    <!-- #ifdef MP-WEIXIN -->
    <button open-type="contact">联系客服</button>
    <!-- #endif -->

    <view class="search-bar">
      <input
        v-model="keyword"
        placeholder="搜索商品"
        confirm-type="search"
        @confirm="onSearch"
      />
    </view>

    <view class="product-list">
      <view
        v-for="item in products"
        :key="item.id"
        class="product-card"
        @tap="goDetail(item.id)"
      >
        <image :src="item.image" mode="aspectFill" class="product-img" />
        <view class="product-info">
          <text class="product-name">{{ item.name }}</text>
          <text class="product-price">¥{{ item.price }}</text>
        </view>
      </view>
    </view>

    <!-- 加载状态 -->
    <view v-if="loading" class="loading">
      <text>加载中...</text>
    </view>
    <view v-if="noMore" class="no-more">
      <text>没有更多了</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { getProducts } from '@/api/product';
import type { Product } from '@/types';

const keyword = ref('');
const products = ref<Product[]>([]);
const loading = ref(false);
const noMore = ref(false);
const page = ref(1);

// 页面生命周期
onMounted(() => {
  loadProducts();
});

// onShow / onHide 通过 uni 生命周期
onShow(() => {
  console.log('页面显示');
});

onHide(() => {
  console.log('页面隐藏');
});

// 下拉刷新
onPullDownRefresh(async () => {
  page.value = 1;
  noMore.value = false;
  await loadProducts();
  uni.stopPullDownRefresh();
});

// 上拉加载更多
onReachBottom(() => {
  if (!loading.value && !noMore.value) {
    page.value++;
    loadProducts();
  }
});

async function loadProducts() {
  loading.value = true;
  try {
    const res = await getProducts({ keyword: keyword.value, page: page.value });
    if (page.value === 1) {
      products.value = res.data;
    } else {
      products.value.push(...res.data);
    }
    if (res.data.length < 10) noMore.value = true;
  } finally {
    loading.value = false;
  }
}

function onSearch() {
  page.value = 1;
  noMore.value = false;
  loadProducts();
}

function goDetail(id: string) {
  uni.navigateTo({ url: `/pages/product/detail?id=${id}` });
}
</script>

<style lang="scss" scoped>
.container {
  padding: 16rpx;
}

.search-bar {
  input {
    background: #f5f5f5;
    border-radius: 32rpx;
    padding: 16rpx 24rpx;
    font-size: 28rpx;
  }
}

.product-list {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
  margin-top: 16rpx;
}

.product-card {
  width: calc(50% - 8rpx);
  background: #fff;
  border-radius: 12rpx;
  overflow: hidden;
}

.product-img {
  width: 100%;
  height: 340rpx;
}

.product-info {
  padding: 16rpx;
}

.product-name {
  font-size: 28rpx;
  color: #333;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
}

.product-price {
  font-size: 32rpx;
  color: #ff4d4f;
  font-weight: bold;
  margin-top: 8rpx;
  display: block;
}
</style>
```

### 5. 组件通信

```vue
<!-- components/ProductCard.vue -->
<template>
  <view class="card" @tap="$emit('tap', product.id)">
    <image :src="product.image" mode="aspectFill" />
    <text>{{ product.name }}</text>
    <text class="price">¥{{ product.price }}</text>
  </view>
</template>

<script setup lang="ts">
import type { Product } from '@/types';

// Props
const props = defineProps<{
  product: Product;
}>();

// Emits
const emit = defineEmits<{
  tap: [id: string];
  addCart: [product: Product];
}>();
</script>

<!-- 父组件使用 -->
<template>
  <ProductCard
    v-for="item in products"
    :key="item.id"
    :product="item"
    @tap="onTap"
    @add-cart="onAddCart"
  />
</template>

<!-- provide / inject — 跨层级通信 -->
<!-- 祖先组件 -->
<script setup lang="ts">
import { provide, ref } from 'vue';
const theme = ref('light');
provide('theme', theme);
</script>

<!-- 后代组件 -->
<script setup lang="ts">
import { inject } from 'vue';
const theme = inject<Ref<string>>('theme');
</script>
```

### 6. 状态管理 — Pinia

```ts
// store/user.ts
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { login as loginApi, getUserInfo } from '@/api/user';

export const useUserStore = defineStore('user', () => {
  const token = ref(uni.getStorageSync('token') || '');
  const userInfo = ref<UserInfo | null>(null);

  const isLoggedIn = computed(() => !!token.value);

  async function login(phone: string, code: string) {
    const res = await loginApi({ phone, code });
    token.value = res.token;
    userInfo.value = res.user;
    uni.setStorageSync('token', res.token);
  }

  async function fetchUserInfo() {
    if (!token.value) return;
    userInfo.value = await getUserInfo();
  }

  function logout() {
    token.value = '';
    userInfo.value = null;
    uni.removeStorageSync('token');
  }

  return { token, userInfo, isLoggedIn, login, fetchUserInfo, logout };
});

// store/cart.ts
export const useCartStore = defineStore('cart', () => {
  const items = ref<CartItem[]>([]);

  const totalCount = computed(() =>
    items.value.reduce((sum, item) => sum + item.quantity, 0)
  );

  const totalPrice = computed(() =>
    items.value.reduce((sum, item) => sum + item.price * item.quantity, 0)
  );

  function addItem(product: Product) {
    const existing = items.value.find((i) => i.id === product.id);
    if (existing) {
      existing.quantity++;
    } else {
      items.value.push({ ...product, quantity: 1 });
    }
  }

  function removeItem(id: string) {
    const index = items.value.findIndex((i) => i.id === id);
    if (index > -1) items.value.splice(index, 1);
  }

  function clear() {
    items.value = [];
  }

  return { items, totalCount, totalPrice, addItem, removeItem, clear };
});

// store/index.ts
import { createPinia } from 'pinia';
export const pinia = createPinia();

// main.ts
import { createSSRApp } from 'vue';
import { pinia } from './store';
import App from './App.vue';

export function createApp() {
  const app = createSSRApp(App);
  app.use(pinia);
  return { app };
}
```

### 7. 网络请求封装

```ts
// api/request.ts
const BASE_URL = 'https://api.example.com';

interface RequestOptions {
  url: string;
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  data?: any;
  header?: Record<string, string>;
}

interface ApiResponse<T = any> {
  code: number;
  data: T;
  message: string;
}

export function request<T = any>(options: RequestOptions): Promise<ApiResponse<T>> {
  return new Promise((resolve, reject) => {
    const token = uni.getStorageSync('token');

    uni.request({
      url: BASE_URL + options.url,
      method: options.method || 'GET',
      data: options.data,
      header: {
        'Content-Type': 'application/json',
        Authorization: token ? `Bearer ${token}` : '',
        ...options.header,
      },
      success: (res) => {
        const data = res.data as ApiResponse<T>;
        if (data.code === 0) {
          resolve(data);
        } else if (data.code === 401) {
          // Token 过期
          uni.removeStorageSync('token');
          uni.navigateTo({ url: '/pages/login/index' });
          reject(new Error('未登录'));
        } else {
          uni.showToast({ title: data.message || '请求失败', icon: 'none' });
          reject(new Error(data.message));
        }
      },
      fail: (err) => {
        uni.showToast({ title: '网络异常', icon: 'none' });
        reject(err);
      },
    });
  });
}

// api/user.ts
import { request } from './request';

export const login = (data: { phone: string; code: string }) =>
  request<{ token: string; user: UserInfo }>({ url: '/auth/login', method: 'POST', data });

export const getUserInfo = () =>
  request<UserInfo>({ url: '/user/info' });

export const updateProfile = (data: Partial<UserInfo>) =>
  request({ url: '/user/profile', method: 'PUT', data });
```

### 8. 条件编译

```vue
<template>
  <!-- 模板条件编译 -->
  <!-- #ifdef MP-WEIXIN -->
  <button open-type="getUserInfo" @getuserinfo="onGetUserInfo">微信登录</button>
  <!-- #endif -->

  <!-- #ifdef MP-ALIPAY -->
  <button @tap="aliLogin">支付宝登录</button>
  <!-- #endif -->

  <!-- #ifdef H5 -->
  <div class="h5-login">
    <input v-model="phone" placeholder="手机号" />
    <button @tap="smsLogin">验证码登录</button>
  </div>
  <!-- #endif -->

  <!-- #ifdef APP-PLUS -->
  <button @tap="appLogin">APP 登录</button>
  <!-- #endif -->

  <!-- 通用（所有端） -->
  <view class="footer">
    <text>© 2024 My App</text>
  </view>
</template>

<script setup lang="ts">
// JS 条件编译
function login() {
  // #ifdef MP-WEIXIN
  wx.login({
    success: (res) => {
      // 微信登录逻辑
    },
  });
  // #endif

  // #ifdef APP-PLUS
  plus.oauth.getServices((services) => {
    // APP 第三方登录
  });
  // #endif

  // #ifndef MP-WEIXIN
  console.log('非微信小程序环境');
  // #endif
}

// CSS 条件编译
// /* #ifdef MP-WEIXIN */
// .container { padding-top: 0; }
// /* #endif */
// /* #ifdef H5 */
// .container { max-width: 750px; margin: 0 auto; }
// /* #endif */
</script>

<style lang="scss" scoped>
/* 条件编译样式 */
/* #ifdef H5 */
.container {
  max-width: 750px;
  margin: 0 auto;
  cursor: pointer;
}
/* #endif */

/* #ifdef MP */
.container {
  padding-bottom: env(safe-area-inset-bottom);
}
/* #endif */
</style>
```

### 9. 路由与页面跳转

```ts
// 普通跳转（有返回按钮）
uni.navigateTo({ url: '/pages/product/detail?id=123' });

// 重定向（替换当前页面）
uni.redirectTo({ url: '/pages/index/index' });

// 关闭所有页面，打开某个页面
uni.reLaunch({ url: '/pages/index/index' });

// 切换 Tab 页
uni.switchTab({ url: '/pages/index/index' });

// 返回
uni.navigateBack({ delta: 1 });

// 接收参数
onLoad((options) => {
  const id = options?.id;
  console.log('Product ID:', id);
});

// 事件通信（页面间传参）
// 页面 A
uni.$emit('productChanged', { id: '123', action: 'delete' });

// 页面 B
onLoad(() => {
  uni.$on('productChanged', (data) => {
    console.log('Product changed:', data);
    // 刷新列表
  });
});
onUnload(() => {
  uni.$off('productChanged');
});
```

### 10. 常用 API

```ts
// 本地存储
uni.setStorageSync('key', 'value');
const val = uni.getStorageSync('key');
uni.removeStorageSync('key');

// 获取系统信息
const info = uni.getSystemInfoSync();
console.log(info.platform, info.windowWidth, info.statusBarHeight);

// 获取用户信息（小程序）
// #ifdef MP-WEIXIN
uni.getUserProfile({
  desc: '用于完善会员资料',
  success: (res) => {
    console.log(res.userInfo);
  },
});
// #endif

// 选择图片
uni.chooseImage({
  count: 9,
  sizeType: ['compressed'],
  sourceType: ['album', 'camera'],
  success: (res) => {
    console.log(res.tempFilePaths);
  },
});

// 上传文件
uni.uploadFile({
  url: 'https://api.example.com/upload',
  filePath: tempFilePath,
  name: 'file',
  header: { Authorization: `Bearer ${token}` },
  success: (res) => {
    console.log(JSON.parse(res.data));
  },
});

// 支付（微信小程序）
// #ifdef MP-WEIXIN
uni.requestPayment({
  provider: 'wxpay',
  timeStamp: order.timeStamp,
  nonceStr: order.nonceStr,
  package: order.package,
  signType: order.signType,
  paySign: order.paySign,
  success: () => { console.log('支付成功'); },
  fail: (err) => { console.log('支付失败', err); },
});
// #endif

// 扫码
uni.scanCode({
  success: (res) => {
    console.log('扫码结果:', res.result);
  },
});

// 地图与定位
uni.getLocation({
  type: 'gcj02',
  success: (res) => {
    console.log(res.latitude, res.longitude);
  },
});
```

### 11. uni-ui 组件库

```vue
<template>
  <!-- 安装: npm install @dcloudio/uni-ui -->
  <!-- 自动引入无需 import -->

  <!-- 导航栏 -->
  <uni-nav-bar left-icon="back" title="商品详情" @click-left="goBack" />

  <!-- 轮播图 -->
  <swiper class="swiper" indicator-dots autoplay>
    <swiper-item v-for="img in images" :key="img">
      <image :src="img" mode="aspectFill" />
    </swiper-item>
  </swiper>

  <!-- 搜索栏 -->
  <uni-search-bar v-model="keyword" placeholder="搜索" @confirm="onSearch" />

  <!-- 下拉选择 -->
  <uni-data-select v-model="category" :localdata="categories" placeholder="选择分类" />

  <!-- 消息提示 -->
  <uni-icons type="heart" size="24" color="#ff4d4f" />

  <!-- 数字角标 -->
  <uni-badge :text="cartCount" type="error">
    <uni-icons type="cart" size="24" />
  </uni-badge>

  <!-- 加载更多 -->
  <uni-load-more :status="loadStatus" />
</template>

<script setup lang="ts">
import { ref } from 'vue';

const keyword = ref('');
const category = ref('');
const cartCount = ref(3);
const loadStatus = ref<'more' | 'loading' | 'noMore'>('more');

const categories = [
  { value: '1', text: '电子产品' },
  { value: '2', text: '服装' },
  { value: '3', text: '食品' },
];

const images = [
  'https://example.com/1.jpg',
  'https://example.com/2.jpg',
];
</script>
```

### 12. 性能优化

```ts
// 1. 分包加载 — 减少主包体积
// pages.json 中配置 subPackages（见上文）

// 预下载分包
{
  "preloadRule": {
    "pages/index/index": {
      "network": "all",
      "packages": ["pages-sub/order"]
    }
  }
}

// 2. 图片优化
// - 使用 webp 格式
// - 小图标用 base64 或 iconfont
// - 大图使用懒加载
<image :src="item.image" mode="aspectFill" lazy-load />

// 3. 长列表优化 — 使用虚拟列表
// 安装 uni-app 虚拟列表插件或使用 uView 的 u-waterfall

// 4. 减少 setData 数据量
// ❌ 传递整个大对象
this.list = hugeList;
// ✅ 只更新变化的部分
this.list[index].name = newName;

// 5. 避免频繁触发响应式
import { shallowRef, triggerRef } from 'vue';
const list = shallowRef<Product[]>([]);
// 批量更新后手动触发
list.value = newList;
triggerRef(list);

// 6. 使用 nvue 页面（Weex 渲染）处理复杂动画
// pages.json: { "path": "pages/animation/index", "style": { "navigationStyle": "custom" } }
// 文件后缀 .nvue 使用原生渲染，性能更好

// 7. 合理使用缓存
const CACHE_KEY = 'product_list';
const CACHE_TIME = 5 * 60 * 1000; // 5 分钟

function getCachedData<T>(key: string): T | null {
  const cached = uni.getStorageSync(key);
  if (cached && Date.now() - cached.time < CACHE_TIME) {
    return cached.data;
  }
  return null;
}

function setCachedData<T>(key: string, data: T) {
  uni.setStorageSync(key, { data, time: Date.now() });
}
```

## Common Patterns

### 1. 登录授权流程

```ts
// utils/auth.ts
export async function wxLogin(): Promise<{ token: string }> {
  return new Promise((resolve, reject) => {
    uni.login({
      provider: 'weixin',
      success: (loginRes) => {
        // 将 code 发送到后端换取 token
        request<{ token: string }>({
          url: '/auth/wx-login',
          method: 'POST',
          data: { code: loginRes.code },
        }).then(resolve).catch(reject);
      },
      fail: reject,
    });
  });
}

// 检查登录状态
export function checkLogin(): boolean {
  const token = uni.getStorageSync('token');
  if (!token) {
    uni.navigateTo({ url: '/pages/login/index' });
    return false;
  }
  return true;
}
```

### 2. 小程序分享

```ts
// 页面内配置分享
onShareAppMessage(() => {
  return {
    title: '推荐一个好商品',
    path: '/pages/product/detail?id=123',
    imageUrl: 'https://example.com/share.jpg',
  };
});

// 分享到朋友圈（微信小程序）
onShareTimeline(() => {
  return {
    title: '推荐一个好商品',
    query: 'id=123',
    imageUrl: 'https://example.com/share.jpg',
  };
});
```

### 3. 全局过滤器与工具

```ts
// utils/format.ts
export function formatPrice(price: number): string {
  return `¥${price.toFixed(2)}`;
}

export function formatDate(date: string | Date, fmt = 'YYYY-MM-DD HH:mm'): string {
  const d = new Date(date);
  const map: Record<string, number> = {
    YYYY: d.getFullYear(),
    MM: d.getMonth() + 1,
    DD: d.getDate(),
    HH: d.getHours(),
    mm: d.getMinutes(),
    ss: d.getSeconds(),
  };
  return Object.entries(map).reduce(
    (str, [key, val]) => str.replace(key, String(val).padStart(2, '0')),
    fmt
  );
}

export function formatPhone(phone: string): string {
  return phone.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2');
}
```

### 4. 多端适配策略

```ts
// utils/platform.ts
export function getPlatform(): 'mp-weixin' | 'mp-alipay' | 'h5' | 'app' {
  // #ifdef MP-WEIXIN
  return 'mp-weixin';
  // #endif
  // #ifdef MP-ALIPAY
  return 'mp-alipay';
  // #endif
  // #ifdef H5
  return 'h5';
  // #endif
  // #ifdef APP-PLUS
  return 'app';
  // #endif
  return 'h5'; // fallback
}

// rpx 适配（推荐使用 rpx 单位，自动适配不同屏幕）
// 750rpx = 屏幕宽度
// 1px = 2rpx（在 iPhone 6 上）

// 获取安全区域
const systemInfo = uni.getSystemInfoSync();
const safeAreaBottom = systemInfo.safeAreaInsets?.bottom || 0;
```

## References

- [UniApp 官方文档](https://uniapp.dcloud.net.cn/)
- [UniApp API 文档](https://uniapp.dcloud.net.cn/api/)
- [UniApp 组件文档](https://uniapp.dcloud.net.cn/component/)
- [uni-ui 组件库](https://uniapp.dcloud.net.cn/component/uniui/uni-ui.html)
- [Pinia 状态管理](https://pinia.vuejs.org/zh/)
- [Vue3 文档](https://vuejs.org/)
- [条件编译文档](https://uniapp.dcloud.net.cn/tutorial/platform.html)
- [UniApp 性能优化](https://uniapp.dcloud.net.cn/tutorial/performance.html)
- [HBuilderX IDE](https://www.dcloud.io/hbuilderx.html)
- [DCloud 插件市场](https://ext.dcloud.net.cn/)
