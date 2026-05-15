---
name: wechat-mp
description: 微信小程序原生开发技能。覆盖微信小程序框架、WXML/WXSS、组件化开发、云开发（云函数/云数据库/云存储）、订阅消息、微信支付、分享、授权登录、开放能力及性能优化。适用于微信生态内的小程序开发。
---

# 微信小程序开发

## When to Use This Skill

- 用户需要开发微信小程序（WeChat Mini Program）
- 使用微信原生框架（WXML + WXSS + JS/TS）或 TypeScript 增强方案
- 涉及页面开发、组件化、自定义组件、云开发等
- 需要集成微信支付、订阅消息、分享、授权登录等微信能力
- 需要使用云函数、云数据库、云存储等 Serverless 能力
- 需要优化小程序性能（启动速度、渲染性能、包体积）

## Not For / Boundaries

- **不适用于**跨平台小程序开发（使用 uni-app 或 Taro 技能）
- **不适用于**微信公众号 / 企业微信 H5 开发
- **不适用于**微信开放平台的第三方应用开发
- **不涵盖**微信支付商户后台配置（需商户自行完成）
- 对于需要多端发布的项目，建议使用 uni-app 而非原生开发

## Quick Reference

### 1. 项目初始化

```bash
# 使用微信开发者工具创建项目
# 1. 下载微信开发者工具 → https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html
# 2. 新建项目 → 选择目录 → 填写 AppID
# 3. 选择模板（空项目 / 云开发 / TypeScript）

# 使用 CLI（可选）
npm install -g @wechat-miniprogram/cli
miniprogram init my-app
```

### 2. 项目结构

```
miniprogram/
├── pages/                   # 页面
│   ├── index/
│   │   ├── index.wxml       # 模板
│   │   ├── index.wxss       # 样式
│   │   ├── index.ts         # 逻辑（TypeScript）
│   │   └── index.json       # 页面配置
│   ├── product/
│   │   └── detail/
│   └── order/
│       ├── list/
│       └── detail/
├── components/              # 自定义组件
│   ├── product-card/
│   │   ├── product-card.wxml
│   │   ├── product-card.wxss
│   │   ├── product-card.ts
│   │   └── product-card.json
│   └── nav-bar/
├── services/                # API 服务层
│   ├── api.ts
│   ├── user.ts
│   └── product.ts
├── utils/                   # 工具函数
│   ├── request.ts
│   ├── storage.ts
│   └── format.ts
├── store/                   # 状态管理（可选）
│   └── index.ts
├── static/                  # 静态资源
│   ├── images/
│   └── icons/
├── cloud/                   # 云函数（如使用云开发）
│   └── functions/
│       ├── login/
│       │   ├── index.js
│       │   └── package.json
│       └── getProducts/
├── app.ts                   # 应用入口
├── app.json                 # 全局配置
├── app.wxss                 # 全局样式
└── project.config.json      # 项目配置
```

### 3. 全局配置 — app.json

```json
{
  "pages": [
    "pages/index/index",
    "pages/product/detail/detail",
    "pages/order/list/list",
    "pages/order/detail/detail",
    "pages/login/login"
  ],
  "subpackages": [
    {
      "root": "pages-sub/mine",
      "pages": [
        "profile/profile",
        "settings/settings",
        "address/address"
      ]
    }
  ],
  "tabBar": {
    "color": "#999999",
    "selectedColor": "#07C160",
    "backgroundColor": "#ffffff",
    "borderStyle": "black",
    "list": [
      {
        "pagePath": "pages/index/index",
        "text": "首页",
        "iconPath": "static/icons/home.png",
        "selectedIconPath": "static/icons/home-active.png"
      },
      {
        "pagePath": "pages/order/list/list",
        "text": "订单",
        "iconPath": "static/icons/order.png",
        "selectedIconPath": "static/icons/order-active.png"
      }
    ]
  },
  "window": {
    "navigationBarBackgroundColor": "#ffffff",
    "navigationBarTitleText": "My App",
    "navigationBarTextStyle": "black",
    "backgroundColor": "#f5f5f5"
  },
  "permission": {
    "scope.userLocation": {
      "desc": "用于获取您的位置信息"
    }
  },
  "requiredPrivateInfos": ["getLocation", "chooseAddress"],
  "lazyCodeLoading": "requiredComponents"
}
```

### 4. 页面开发

```xml
<!-- pages/index/index.wxml -->
<view class="container">
  <!-- 数据绑定 -->
  <view class="header">
    <text class="title">{{title}}</text>
    <text class="count">共 {{products.length}} 件商品</text>
  </view>

  <!-- 条件渲染 -->
  <view wx:if="{{loading}}" class="loading">
    <view class="loading-spinner" />
  </view>

  <!-- 列表渲染 -->
  <view wx:else class="product-list">
    <view
      wx:for="{{products}}"
      wx:key="id"
      class="product-card"
      bind:tap="goDetail"
      data-id="{{item.id}}"
    >
      <image src="{{item.image}}" mode="aspectFill" class="product-img" lazy-load />
      <view class="product-info">
        <text class="product-name">{{item.name}}</text>
        <view class="price-row">
          <text class="price">¥{{item.price}}</text>
          <text class="original-price" wx:if="{{item.originalPrice}}">¥{{item.originalPrice}}</text>
        </view>
      </view>
    </view>
  </view>

  <!-- 空状态 -->
  <view wx:if="{{!loading && products.length === 0}}" class="empty">
    <image src="/static/images/empty.png" class="empty-img" />
    <text class="empty-text">暂无商品</text>
  </view>
</view>
```

```typescript
// pages/index/index.ts
import { getProducts } from '../../services/product';
import type { Product } from '../../types';

Page({
  data: {
    title: '热门商品',
    products: [] as Product[],
    loading: true,
    page: 1,
    hasMore: true,
  },

  onLoad() {
    this.loadProducts();
  },

  onShow() {
    // 页面显示时刷新（如从其他页面返回）
  },

  onPullDownRefresh() {
    this.setData({ page: 1, hasMore: true });
    this.loadProducts().then(() => wx.stopPullDownRefresh());
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.setData({ page: this.data.page + 1 });
      this.loadProducts();
    }
  },

  async loadProducts() {
    this.setData({ loading: true });
    try {
      const res = await getProducts({ page: this.data.page });
      const products = this.data.page === 1
        ? res.data
        : [...this.data.products, ...res.data];

      this.setData({
        products,
        loading: false,
        hasMore: res.data.length >= 10,
      });
    } catch (err) {
      this.setData({ loading: false });
      wx.showToast({ title: '加载失败', icon: 'none' });
    }
  },

  goDetail(e: WechatMiniprogram.TouchEvent) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({ url: `/pages/product/detail/detail?id=${id}` });
  },

  onShareAppMessage(): WechatMiniprogram.Page.ICustomShareContent {
    return {
      title: '发现好物推荐',
      path: '/pages/index/index',
      imageUrl: '/static/images/share.png',
    };
  },
});
```

```css
/* pages/index/index.wxss */
.container {
  padding: 24rpx;
  background: #f5f5f5;
  min-height: 100vh;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24rpx;
}

.title {
  font-size: 36rpx;
  font-weight: bold;
  color: #333;
}

.count {
  font-size: 24rpx;
  color: #999;
}

.product-list {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
}

.product-card {
  width: calc(50% - 8rpx);
  background: #fff;
  border-radius: 16rpx;
  overflow: hidden;
  box-shadow: 0 2rpx 12rpx rgba(0, 0, 0, 0.05);
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

.price-row {
  margin-top: 8rpx;
  display: flex;
  align-items: baseline;
  gap: 8rpx;
}

.price {
  font-size: 32rpx;
  color: #fa5151;
  font-weight: bold;
}

.original-price {
  font-size: 24rpx;
  color: #ccc;
  text-decoration: line-through;
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: 200rpx;
}

.empty-img {
  width: 240rpx;
  height: 240rpx;
}

.empty-text {
  margin-top: 24rpx;
  font-size: 28rpx;
  color: #999;
}
```

### 5. 自定义组件

```xml
<!-- components/product-card/product-card.wxml -->
<view class="card" bind:tap="onTap">
  <image src="{{product.image}}" mode="aspectFill" class="img" lazy-load />
  <view class="info">
    <text class="name">{{product.name}}</text>
    <view class="bottom">
      <text class="price">¥{{product.price}}</text>
      <view class="cart-btn" catch:tap="addToCart" data-product="{{product}}">
        <text class="cart-icon">+</text>
      </view>
    </view>
  </view>
</view>
```

```typescript
// components/product-card/product-card.ts
import type { Product } from '../../types';

Component({
  properties: {
    product: {
      type: Object as () => Product,
      value: {} as Product,
    },
  },

  data: {},

  methods: {
    onTap() {
      this.triggerEvent('tap', { id: this.data.product.id });
    },

    addToCart(e: WechatMiniprogram.TouchEvent) {
      const product = e.currentTarget.dataset.product as Product;
      this.triggerEvent('addcart', { product });
    },
  },
});
```

```json
// components/product-card/product-card.json
{
  "component": true
}
```

```css
/* components/product-card/product-card.wxss */
.card {
  background: #fff;
  border-radius: 16rpx;
  overflow: hidden;
  box-shadow: 0 2rpx 12rpx rgba(0, 0, 0, 0.05);
}

.img {
  width: 100%;
  height: 340rpx;
}

.info {
  padding: 16rpx;
}

.name {
  font-size: 28rpx;
  color: #333;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
}

.bottom {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 12rpx;
}

.price {
  font-size: 32rpx;
  color: #fa5151;
  font-weight: bold;
}

.cart-btn {
  width: 48rpx;
  height: 48rpx;
  background: #07c160;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.cart-icon {
  color: #fff;
  font-size: 32rpx;
  line-height: 1;
}
```

```json
// 使用组件的页面 index.json
{
  "usingComponents": {
    "product-card": "/components/product-card/product-card"
  }
}
```

```xml
<!-- 页面中使用 -->
<product-card
  wx:for="{{products}}"
  wx:key="id"
  product="{{item}}"
  bind:tap="onProductTap"
  bind:addcart="onAddCart"
/>
```

### 6. 网络请求封装

```typescript
// utils/request.ts
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

function getToken(): string {
  return wx.getStorageSync('token') || '';
}

export function request<T = any>(options: RequestOptions): Promise<ApiResponse<T>> {
  return new Promise((resolve, reject) => {
    wx.request({
      url: BASE_URL + options.url,
      method: options.method || 'GET',
      data: options.data,
      header: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${getToken()}`,
        ...options.header,
      },
      success(res) {
        const data = res.data as ApiResponse<T>;
        if (data.code === 0) {
          resolve(data);
        } else if (data.code === 401) {
          wx.removeStorageSync('token');
          wx.navigateTo({ url: '/pages/login/login' });
          reject(new Error('未登录'));
        } else {
          wx.showToast({ title: data.message || '请求失败', icon: 'none' });
          reject(new Error(data.message));
        }
      },
      fail(err) {
        wx.showToast({ title: '网络异常', icon: 'none' });
        reject(err);
      },
    });
  });
}

// services/product.ts
import { request } from '../utils/request';
import type { Product } from '../types';

export const getProducts = (params: { page: number; keyword?: string }) =>
  request<Product[]>({ url: '/products', data: params });

export const getProductDetail = (id: string) =>
  request<Product>({ url: `/products/${id}` });

// services/user.ts
export const wxLogin = (code: string) =>
  request<{ token: string; user: UserInfo }>({ url: '/auth/wx-login', method: 'POST', data: { code } });

export const getUserInfo = () =>
  request<UserInfo>({ url: '/user/info' });
```

### 7. 微信登录与授权

```typescript
// 微信登录流程
async function login(): Promise<void> {
  try {
    // 1. wx.login 获取 code
    const loginRes = await new Promise<WechatMiniprogram.LoginSuccessCallbackResult>((resolve, reject) => {
      wx.login({ success: resolve, fail: reject });
    });

    // 2. 发送 code 到后端换取 token
    const res = await wxLogin(loginRes.code);
    wx.setStorageSync('token', res.token);
    wx.setStorageSync('user', res.user);

    // 3. 获取用户信息（需要用户点击授权按钮）
    // 注意：wx.getUserProfile 已废弃，现使用 button + open-type="chooseAvatar"
    // 或通过头像昵称填写能力获取
  } catch (err) {
    console.error('登录失败:', err);
    wx.showToast({ title: '登录失败', icon: 'none' });
  }
}

// 获取头像（新方式 — 2022年后）
// WXML:
// <button open-type="chooseAvatar" bind:chooseavatar="onChooseAvatar">
//   <image src="{{avatarUrl}}" />
// </button>

// TS:
function onChooseAvatar(e: WechatMiniprogram.ChooseAvatarSuccessCallbackResult) {
  const avatarUrl = e.detail.avatarUrl;
  this.setData({ avatarUrl });
  // 上传到服务器
}

// 获取昵称（新方式）
// WXML:
// <input type="nickname" bind:input="onNickNameInput" placeholder="请输入昵称" />

// 手机号获取（需要用户主动点击）
// WXML:
// <button open-type="getPhoneNumber" bind:getphonenumber="onGetPhoneNumber">获取手机号</button>

// TS:
async function onGetPhoneNumber(e: WechatMiniprogram.GetPhoneNumberSuccessCallbackResult) {
  if (e.detail.code) {
    // 将 code 发送到后端，后端调用 phonenumber.getPhoneNumber 接口获取手机号
    const res = await request({
      url: '/auth/phone',
      method: 'POST',
      data: { code: e.detail.code },
    });
  }
}
```

### 8. 微信支付

```typescript
// services/payment.ts
import { request } from '../utils/request';

// 1. 创建订单（后端）
export async function createOrder(orderData: {
  productId: string;
  quantity: number;
  addressId: string;
}) {
  return request<{
    orderId: string;
    payment: WechatMiniprogram.RequestPaymentOption;
  }>({ url: '/orders', method: 'POST', data: orderData });
}

// 2. 发起支付
async function payOrder(orderId: string) {
  wx.showLoading({ title: '发起支付...' });

  try {
    const { payment } = await createOrder({ productId: 'xxx', quantity: 1, addressId: 'xxx' });

    wx.hideLoading();

    // 调用微信支付
    await new Promise<void>((resolve, reject) => {
      wx.requestPayment({
        timeStamp: payment.timeStamp,
        nonceStr: payment.nonceStr,
        package: payment.package,
        signType: payment.signType as 'MD5' | 'HMAC-SHA256' | 'RSA',
        paySign: payment.paySign,
        success: () => {
          wx.showToast({ title: '支付成功', icon: 'success' });
          resolve();
        },
        fail: (err) => {
          if (err.errMsg.includes('cancel')) {
            wx.showToast({ title: '已取消支付', icon: 'none' });
          } else {
            wx.showToast({ title: '支付失败', icon: 'none' });
          }
          reject(err);
        },
      });
    });

    // 支付成功，跳转到订单详情
    wx.navigateTo({ url: `/pages/order/detail/detail?id=${orderId}` });
  } catch (err) {
    wx.hideLoading();
  }
}
```

### 9. 云开发

```typescript
// 初始化云开发 — app.ts
App({
  onLaunch() {
    if (!wx.cloud) {
      console.error('请使用 2.2.3 或以上的基础库以使用云能力');
    } else {
      wx.cloud.init({
        env: 'your-env-id', // 云开发环境 ID
        traceUser: true,
      });
    }
  },
});

// ========== 云函数 ==========
// cloud/functions/login/index.js
const cloud = require('wx-server-sdk');
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();

exports.main = async (event, context) => {
  const wxContext = cloud.getWXContext();
  const openid = wxContext.OPENID;

  // 查找或创建用户
  let user = await db.collection('users').where({ openid }).get();
  if (user.data.length === 0) {
    await db.collection('users').add({
      data: {
        openid,
        nickname: '',
        avatar: '',
        createdAt: db.serverDate(),
      },
    });
    user = await db.collection('users').where({ openid }).get();
  }

  return {
    openid,
    user: user.data[0],
  };
};

// cloud/functions/getProducts/index.js
exports.main = async (event) => {
  const { page = 1, pageSize = 10, keyword } = event;
  const db = cloud.database();
  const _ = db.command;
  const collection = db.collection('products');

  let query = collection;
  if (keyword) {
    query = query.where({
      name: db.RegExp({ regexp: keyword, options: 'i' }),
    });
  }

  const res = await query
    .skip((page - 1) * pageSize)
    .limit(pageSize)
    .orderBy('createdAt', 'desc')
    .get();

  return res.data;
};

// ========== 小程序端调用云函数 ==========
async function loginWithCloud() {
  const res = await wx.cloud.callFunction({ name: 'login' });
  const { openid, user } = res.result as any;
  console.log('OpenID:', openid);
  return user;
}

async function fetchProducts(page: number) {
  const res = await wx.cloud.callFunction({
    name: 'getProducts',
    data: { page, pageSize: 10 },
  });
  return res.result as Product[];
}

// ========== 云数据库（小程序端直接操作） ==========
const db = wx.cloud.database();
const _ = db.command;

// 查询
const { data } = await db.collection('products')
  .where({ price: _.gt(100) })
  .orderBy('price', 'asc')
  .limit(20)
  .get();

// 新增
await db.collection('products').add({
  data: {
    name: '新商品',
    price: 99.9,
    createdAt: db.serverDate(),
  },
});

// 更新
await db.collection('products').doc('product-id').update({
  data: { price: 88.8 },
});

// 删除
await db.collection('products').doc('product-id').remove();

// ========== 云存储 ==========
// 上传文件
const uploadRes = await wx.cloud.uploadFile({
  cloudPath: `images/${Date.now()}.jpg`,
  filePath: tempFilePath, // 临时文件路径
});
console.log('File ID:', uploadRes.fileID);

// 下载文件
const downloadRes = await wx.cloud.downloadFile({
  fileID: 'cloud://xxx/xxx.jpg',
});
console.log('临时路径:', downloadRes.tempFilePath);

// 获取临时链接
const { fileList } = await wx.cloud.getTempFileURL({
  fileList: ['cloud://xxx/xxx.jpg'],
});
console.log('URL:', fileList[0].tempFileURL);
```

### 10. 订阅消息

```typescript
// 请求订阅消息授权
async function requestSubscribeMessage() {
  try {
    const res = await wx.requestSubscribeMessage({
      tmplIds: [
        'template-id-1', // 订单状态通知
        'template-id-2', // 发货通知
      ],
    });
    console.log('订阅结果:', res);
    // res = { 'template-id-1': 'accept', 'template-id-2': 'reject' }
  } catch (err) {
    console.error('订阅失败:', err);
  }
}

// 在合适时机触发（如下单时）
<button bind:tap="requestSubscribeMessage">接收通知</button>

// 后端发送订阅消息（云函数）
// cloud/functions/sendMessage/index.js
exports.main = async (event) => {
  const { openid, orderId, status } = event;

  try {
    const result = await cloud.openapi.subscribeMessage.send({
      touser: openid,
      templateId: 'template-id-1',
      page: `/pages/order/detail/detail?id=${orderId}`,
      data: {
        thing1: { value: '订单状态更新' },
        character_string2: { value: orderId },
        thing3: { value: status },
      },
    });
    return result;
  } catch (err) {
    console.error('发送失败:', err);
    return { errCode: err.errCode, errMsg: err.errMsg };
  }
};
```

### 11. 分享能力

```typescript
// 转发给朋友
onShareAppMessage(): WechatMiniprogram.Page.ICustomShareContent {
  return {
    title: '发现一个好商品',
    path: '/pages/product/detail/detail?id=123',
    imageUrl: '/static/images/share-cover.jpg', // 自定义封面
  };
}

// 分享到朋友圈
onShareTimeline(): WechatMiniprogram.Page.ICustomShareTimelineContent {
  return {
    title: '发现一个好商品',
    query: 'id=123',
    imageUrl: '/static/images/share-cover.jpg',
  };
}

// 生成小程序码（后端/云函数）
// cloud/functions/genQRCode/index.js
exports.main = async (event) => {
  const { scene, page } = event;

  const result = await cloud.openapi.wxacode.getUnlimited({
    scene,  // 最大32个字符
    page,   // 必须是已发布的小程序页面
    width: 280,
  });

  // 上传到云存储
  const uploadRes = await cloud.uploadFile({
    cloudPath: `qrcode/${scene}.jpg`,
    fileContent: result.buffer,
  });

  return { fileID: uploadRes.fileID };
};
```

### 12. 本地存储

```typescript
// 同步存储
wx.setStorageSync('token', 'xxx');
wx.setStorageSync('user', JSON.stringify(userInfo));

const token = wx.getStorageSync('token');
const user = JSON.parse(wx.getStorageSync('user') || 'null');

wx.removeStorageSync('token');
wx.clearStorageSync();

// 异步存储（推荐大数据量）
wx.setStorage({
  key: 'products',
  data: largeArray,
  success() { console.log('存储成功'); },
});

wx.getStorage({
  key: 'products',
  success(res) { console.log(res.data); },
});

// 获取存储信息
const info = wx.getStorageInfoSync();
console.log('当前占用:', info.currentSize, 'KB');
console.log('限制:', info.limitSize, 'KB');
```

### 13. 性能优化

```typescript
// 1. 分包加载
// app.json 中配置 subpackages（见上文）

// 预下载分包
// app.json
{
  "preloadRule": {
    "pages/index/index": {
      "network": "all",
      "packages": ["pages-sub/mine"]
    }
  }
}

// 2. 按需注入 & 懒注入
// app.json
{
  "lazyCodeLoading": "requiredComponents"
}

// 3. 图片优化
// - 使用 webp 格式
// - CDN 图片处理（裁剪、压缩）
<image src="{{item.image}}?x-oss-process=image/resize,w_300/format,webp" />

// 4. 长列表优化 — 虚拟列表
// 使用 recycle-view 组件
// npm install miniprogram-recycle-view

// 5. 减少 setData 数据量
// ❌ 传递整个大对象
this.setData({ list: hugeList });
// ✅ 路径更新
this.setData({ 'list[0].name': 'new name' });

// 6. 合并 setData 调用
// ❌ 多次 setData
this.setData({ a: 1 });
this.setData({ b: 2 });
this.setData({ c: 3 });
// ✅ 合并
this.setData({ a: 1, b: 2, c: 3 });

// 7. 避免在 onPageScroll 中频繁 setData
let scrollTimer: number;
onPageScroll(e) {
  clearTimeout(scrollTimer);
  scrollTimer = setTimeout(() => {
    this.setData({ scrollTop: e.scrollTop });
  }, 100);
}

// 8. 使用 IntersectionObserver 替代 scroll 监听
const observer = wx.createIntersectionObserver(this);
observer.relativeToViewport().observe('.target-element', (res) => {
  if (res.intersectionRatio > 0) {
    // 元素进入视口
  }
});

// 9. 骨架屏
// 开发者工具 → 详情 → 本地设置 → 勾选"启用骨架屏"
// 或手写骨架屏组件

// 10. 数据预拉取 & 周期性更新
// app.json
{
  "preloadRule": { ... },
  "res": {
    "prefetch": [
      {
        "url": "https://api.example.com/config",
        "query": ""
      }
    ]
  }
}
```

### 14. 调试技巧

```typescript
// 控制台日志
console.log('Debug:', data);
console.warn('Warning');
console.error('Error:', err);

// 真机调试
// 微信开发者工具 → 调试 → 真机调试 → 扫码

// vConsole（真机上的控制台）
// app.json
{ "setting": { "enableVConsole": true } }

// 性能面板
// 微信开发者工具 → Audits → 性能评分

// 网络请求查看
// 微信开发者工具 → Network 面板

// 远程调试
// 微信开发者工具 → 调试 → 远程调试
```

## Common Patterns

### 1. 登录授权完整流程

```typescript
// utils/auth.ts
export class AuthService {
  private static instance: AuthService;
  static getInstance() {
    if (!this.instance) this.instance = new AuthService();
    return this.instance;
  }

  async login(): Promise<UserInfo> {
    // 1. 获取 code
    const { code } = await this.wxLogin();

    // 2. 后端换取 token
    const res = await wxLogin(code);
    wx.setStorageSync('token', res.token);
    wx.setStorageSync('user', JSON.stringify(res.user));

    return res.user;
  }

  private wxLogin(): Promise<{ code: string }> {
    return new Promise((resolve, reject) => {
      wx.login({ success: resolve, fail: reject });
    });
  }

  isLoggedIn(): boolean {
    return !!wx.getStorageSync('token');
  }

  getUser(): UserInfo | null {
    const str = wx.getStorageSync('user');
    return str ? JSON.parse(str) : null;
  }

  logout() {
    wx.removeStorageSync('token');
    wx.removeStorageSync('user');
    wx.reLaunch({ url: '/pages/index/index' });
  }
}

// app.ts
App({
  globalData: {
    userInfo: null as UserInfo | null,
  },

  async onLaunch() {
    const auth = AuthService.getInstance();
    if (auth.isLoggedIn()) {
      this.globalData.userInfo = auth.getUser();
    }
  },
});
```

### 2. 全局状态管理（简易版）

```typescript
// store/index.ts
class Store {
  private listeners: Map<string, Set<Function>> = new Map();

  // 发布
  emit(event: string, data?: any) {
    this.listeners.get(event)?.forEach((fn) => fn(data));
  }

  // 订阅
  on(event: string, fn: Function) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(fn);
  }

  // 取消订阅
  off(event: string, fn: Function) {
    this.listeners.get(event)?.delete(fn);
  }
}

export const store = new Store();

// 使用
store.on('cartUpdated', (count: number) => {
  this.setData({ cartCount: count });
  wx.setTabBarBadge({ index: 1, text: String(count) });
});

store.emit('cartUpdated', 5);
```

### 3. 图片预览与上传

```typescript
// 预览图片
function previewImage(urls: string[], current: string) {
  wx.previewImage({ urls, current });
}

// 选择并上传图片
async function chooseAndUpload(count = 1): Promise<string[]> {
  const chooseRes = await new Promise<WechatMiniprogram.ChooseImageSuccessCallbackResult>((resolve, reject) => {
    wx.chooseImage({
      count,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      success: resolve,
      fail: reject,
    });
  });

  const uploadPromises = chooseRes.tempFilePaths.map(async (filePath) => {
    const res = await wx.cloud.uploadFile({
      cloudPath: `uploads/${Date.now()}-${Math.random().toString(36).slice(2)}.jpg`,
      filePath,
    });
    return res.fileID;
  });

  return Promise.all(uploadPromises);
}
```

### 4. 地图与定位

```typescript
// 获取当前位置
async function getCurrentLocation() {
  return new Promise<WechatMiniprogram.GetLocationSuccessCallbackResult>((resolve, reject) => {
    wx.getLocation({
      type: 'gcj02',
      success: resolve,
      fail: reject,
    });
  });
}

// 打开地图选择位置
async function chooseLocation() {
  return new Promise<WechatMiniprogram.ChooseLocationSuccessCallbackResult>((resolve, reject) => {
    wx.chooseLocation({ success: resolve, fail: reject });
  });
}

// 使用地图组件
// WXML:
// <map
//   id="map"
//   longitude="{{longitude}}"
//   latitude="{{latitude}}"
//   scale="16"
//   show-location
//   markers="{{markers}}"
//   bind:tap="onMapTap"
//   style="width: 100%; height: 400rpx;"
// />
```

### 5. 场景值与启动参数

```typescript
App({
  onLaunch(options) {
    // 启动参数
    console.log('场景值:', options.scene);
    console.log('路径:', options.path);
    console.log('参数:', options.query);

    // 常见场景值
    // 1001: 发现页进入
    // 1007: 单人聊天会话分享
    // 1011: 扫描二维码
    // 1012: 长按图片识别二维码
    // 1036: 分享消息卡片

    // 根据场景处理
    if (options.scene === 1007 || options.scene === 1036) {
      // 从分享进入，跳转到对应页面
      const { id } = options.query;
      if (id) {
        wx.navigateTo({ url: `/pages/product/detail/detail?id=${id}` });
      }
    }
  },
});
```

## References

- [微信小程序官方文档](https://developers.weixin.qq.com/miniprogram/dev/framework/)
- [小程序 API 文档](https://developers.weixin.qq.com/miniprogram/dev/api/)
- [小程序组件文档](https://developers.weixin.qq.com/miniprogram/dev/component/)
- [云开发文档](https://developers.weixin.qq.com/miniprogram/dev/wxcloud/basis/getting-started.html)
- [订阅消息文档](https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/subscribe-message/)
- [微信支付文档](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_5_1.shtml)
- [小程序性能优化指南](https://developers.weixin.qq.com/miniprogram/dev/framework/performance/)
- [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
- [小程序社区](https://developers.weixin.qq.com/community/)
