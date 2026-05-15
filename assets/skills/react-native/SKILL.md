---
name: react-native
description: React Native 跨平台移动应用开发技能。覆盖 React Native 核心组件、Expo 工作流、React Navigation 路由、状态管理（Redux/Zustand）、原生模块桥接、样式系统、调试工具、OTA 热更新等。适用于 iOS/Android 应用开发。
---

# React Native 跨平台开发

## When to Use This Skill

- 用户需要使用 JavaScript/TypeScript 构建跨平台移动应用（iOS + Android）
- 使用 React Native 或 Expo 框架进行开发
- 涉及组件开发、导航配置、状态管理、网络请求、本地存储等
- 需要通过原生模块桥接调用平台特定功能（相机、推送、生物识别等）
- 需要调试 React Native 应用或配置 OTA 热更新
- 需要优化 React Native 应用性能（启动速度、列表滚动、内存管理）

## Not For / Boundaries

- **不适用于**纯原生 iOS (Swift) 或 Android (Kotlin) 开发（除非需要编写原生模块）
- **不适用于**React Web 应用开发（使用 Next.js / CRA 等）
- **不涵盖**React Native 新架构（Fabric / TurboModules）的深度底层开发
- **不替代**原生 UI 设计工具
- 对于简单展示型应用，考虑 WebView 方案可能更轻量

## Quick Reference

### 1. 项目初始化

```bash
# Expo（推荐 — 开箱即用）
npx create-expo-app@latest my-app --template tabs
cd my-app
npx expo start

# React Native CLI（需要完整原生控制）
npx react-native@latest init MyApp
cd MyApp
npx react-native run-ios     # iOS
npx react-native run-android # Android
```

### 2. 项目结构

```
src/
├── app/                       # Expo Router 页面（或 screens/）
│   ├── (tabs)/                # Tab 布局
│   │   ├── _layout.tsx        # Tab 导航配置
│   │   ├── index.tsx          # 首页 Tab
│   │   └── profile.tsx        # 个人中心 Tab
│   ├── _layout.tsx            # 根布局
│   ├── index.tsx              # 入口页面
│   └── [id].tsx               # 动态路由
├── components/                # 通用组件
│   ├── Button.tsx
│   ├── Card.tsx
│   └── LoadingOverlay.tsx
├── hooks/                     # 自定义 Hooks
│   ├── useAuth.ts
│   └── useApi.ts
├── services/                  # API 服务层
│   ├── api.ts
│   └── auth.service.ts
├── store/                     # 状态管理
│   ├── index.ts
│   └── slices/
├── utils/                     # 工具函数
│   ├── storage.ts
│   └── format.ts
├── types/                     # TypeScript 类型
│   └── index.ts
└── constants/                 # 常量
    ├── colors.ts
    └── layout.ts
```

### 3. 核心组件与样式

```tsx
import { View, Text, StyleSheet, ScrollView, FlatList, TouchableOpacity, Image } from 'react-native';

// 基础组件
function UserCard({ name, avatar }: { name: string; avatar: string }) {
  return (
    <View style={styles.card}>
      <Image source={{ uri: avatar }} style={styles.avatar} />
      <Text style={styles.name}>{name}</Text>
    </View>
  );
}

// 高性能列表
function UserList({ users }: { users: User[] }) {
  return (
    <FlatList
      data={users}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => <UserCard name={item.name} avatar={item.avatar} />}
      ItemSeparatorComponent={() => <View style={styles.separator} />}
      ListEmptyComponent={<Text style={styles.empty}>暂无数据</Text>}
      onEndReached={loadMore}
      onEndReachedThreshold={0.5}
      refreshing={isLoading}
      onRefresh={refresh}
    />
  );
}

// 样式系统 — StyleSheet（类似 CSS 子集）
const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#fff',
    borderRadius: 8,
    // Shadow (iOS)
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    // Shadow (Android)
    elevation: 3,
  },
  avatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  name: {
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 12,
    color: '#1a1a1a',
  },
  separator: {
    height: 8,
  },
  empty: {
    textAlign: 'center',
    color: '#999',
    marginTop: 40,
  },
});
```

### 4. 导航配置 — React Navigation / Expo Router

```tsx
// React Navigation — 手动配置
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

function HomeTabs() {
  return (
    <Tab.Navigator screenOptions={{ tabBarActiveTintColor: '#007AFF' }}>
      <Tab.Screen name="Home" component={HomeScreen} options={{
        tabBarIcon: ({ color, size }) => <Icon name="home" size={size} color={color} />,
      }} />
      <Tab.Screen name="Profile" component={ProfileScreen} options={{
        tabBarIcon: ({ color, size }) => <Icon name="user" size={size} color={color} />,
      }} />
    </Tab.Navigator>
  );
}

export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen name="Main" component={HomeTabs} options={{ headerShown: false }} />
        <Stack.Screen name="ProductDetail" component={ProductDetailScreen} options={{
          title: '商品详情',
          headerBackTitle: '返回',
        }} />
        <Stack.Screen name="Login" component={LoginScreen} options={{
          presentation: 'modal',
        }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

// 导航跳转
navigation.navigate('ProductDetail', { id: '123' });
navigation.push('ProductDetail', { id: '456' });  // 压入新实例
navigation.goBack();

// 接收参数
function ProductDetailScreen({ route }: { route: any }) {
  const { id } = route.params;
  // ...
}

// Expo Router（文件系统路由 — 推荐）
// app/_layout.tsx — 根布局
import { Stack } from 'expo-router';
export default function RootLayout() {
  return <Stack />;
}

// app/(tabs)/_layout.tsx — Tab 布局
import { Tabs } from 'expo-router';
export default function TabLayout() {
  return (
    <Tabs>
      <Tabs.Screen name="index" options={{ title: '首页' }} />
      <Tabs.Screen name="profile" options={{ title: '我的' }} />
    </Tabs>
  );
}

// 跳转
import { router } from 'expo-router';
router.push('/product/123');
router.replace('/login');
router.back();
```

### 5. 状态管理

#### Zustand（推荐 — 轻量、简洁）

```tsx
import { create } from 'zustand';

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  isLoading: false,

  login: async (email, password) => {
    set({ isLoading: true });
    try {
      const { user, token } = await authService.login(email, password);
      set({ user, token, isLoading: false });
      await AsyncStorage.setItem('token', token);
    } catch (error) {
      set({ isLoading: false });
      throw error;
    }
  },

  logout: () => {
    set({ user: null, token: null });
    AsyncStorage.removeItem('token');
  },
}));

// 在组件中使用
function ProfileScreen() {
  const { user, logout } = useAuthStore();
  if (!user) return <LoginPrompt />;
  return (
    <View>
      <Text>{user.name}</Text>
      <Button title="退出" onPress={logout} />
    </View>
  );
}
```

#### Redux Toolkit（大型项目）

```tsx
import { createSlice, createAsyncThunk, configureStore } from '@reduxjs/toolkit';

const fetchUsers = createAsyncThunk('users/fetch', async () => {
  const response = await fetch('https://api.example.com/users');
  return response.json();
});

const usersSlice = createSlice({
  name: 'users',
  initialState: { items: [], loading: false, error: null as string | null },
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(fetchUsers.pending, (state) => { state.loading = true; })
      .addCase(fetchUsers.fulfilled, (state, action) => {
        state.loading = false;
        state.items = action.payload;
      })
      .addCase(fetchUsers.rejected, (state, action) => {
        state.loading = false;
        state.error = action.error.message || 'Failed';
      });
  },
});

const store = configureStore({ reducer: { users: usersSlice.reducer } });

// 使用
function UsersScreen() {
  const dispatch = useDispatch();
  const { items, loading } = useSelector((state: RootState) => state.users);

  useEffect(() => { dispatch(fetchUsers()); }, []);

  if (loading) return <ActivityIndicator />;
  return <FlatList data={items} renderItem={({ item }) => <Text>{item.name}</Text>} />;
}
```

### 6. 网络请求

```tsx
// services/api.ts — Axios 封装
import axios, { AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const api: AxiosInstance = axios.create({
  baseURL: 'https://api.example.com',
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use(async (config: InternalAxiosRequestConfig) => {
  const token = await AsyncStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      await AsyncStorage.removeItem('token');
      // 跳转登录
    }
    return Promise.reject(error);
  }
);

export default api;

// 使用
const getUsers = async (): Promise<User[]> => {
  const { data } = await api.get('/users');
  return data;
};

const createUser = async (user: CreateUserDTO): Promise<User> => {
  const { data } = await api.post('/users', user);
  return data;
};

// 自定义 Hook
function useApi<T>(fetcher: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetcher()
      .then((d) => { if (!cancelled) setData(d); })
      .catch((e) => { if (!cancelled) setError(e.message); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);

  return { data, loading, error };
}
```

### 7. 本地存储

```tsx
// AsyncStorage — 简单键值对
import AsyncStorage from '@react-native-async-storage/async-storage';

// 存储
await AsyncStorage.setItem('user', JSON.stringify(userData));
await AsyncStorage.setItem('token', token);

// 读取
const userJson = await AsyncStorage.getItem('user');
const user = userJson ? JSON.parse(userJson) : null;

// 删除
await AsyncStorage.removeItem('token');
await AsyncStorage.clear();

// MMKV — 高性能（推荐替代 AsyncStorage）
import { MMKV } from 'react-native-mmkv';

const storage = new MMKV();

storage.set('user.name', 'John');
storage.getString('user.name');       // 'John'
storage.set('isLoggedIn', true);
storage.getBoolean('isLoggedIn');      // true
storage.delete('user.name');

// SQLite — 关系型数据
import * as SQLite from 'expo-sqlite';

const db = await SQLite.openDatabaseAsync('myapp.db');

await db.execAsync(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed INTEGER DEFAULT 0
  );
`);

const todos = await db.getAllAsync('SELECT * FROM todos WHERE completed = ?', [0]);
await db.runAsync('INSERT INTO todos (title) VALUES (?)', ['Buy groceries']);
```

### 8. 原生模块桥接

```tsx
// iOS (Swift) — 创建原生模块
// ios/MyModule.swift
import Foundation
import React

@objc(MyModule)
class MyModule: NSObject {
  @objc
  func getBatteryLevel(_ resolve: @escaping RCTPromiseResolveBlock,
                       rejecter reject: @escaping RCTPromiseRejectBlock) {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let level = UIDevice.current.batteryLevel
    resolve(Int(level * 100))
  }

  @objc static func requiresMainQueueSetup() -> Bool { return false }
}

// ios/MyModule.m — 桥接文件
// #import <React/RCTBridgeModule.h>
// @interface RCT_EXTERN_MODULE(MyModule, NSObject)
// RCT_EXTERN_METHOD(getBatteryLevel:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
// @end

// Android (Kotlin)
// android/app/src/main/java/com/myapp/MyModule.kt
class MyModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "MyModule"

    @ReactMethod
    fun getBatteryLevel(promise: Promise) {
        val bm = reactApplicationContext.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        promise.resolve(level)
    }
}

// TypeScript 端调用
import { NativeModules } from 'react-native';
const { MyModule } = NativeModules;
const level = await MyModule.getBatteryLevel();
```

### 9. 调试工具

```tsx
// React Native Debugger（集成 Redux DevTools + Chrome DevTools）
// brew install --cask react-native-debugger

// Flipper（Meta 官方调试工具）
// https://fbflipper.com/

// Console 调试
console.log('Debug:', data);
console.warn('Warning message');
console.error('Error:', error);

// React DevTools
// npx react-devtools

// 性能监控
import { Performance } from 'react-native-performance';
const startTime = performance.now();
// ... 操作
console.log('Duration:', performance.now() - startTime, 'ms');

// LogBox 忽略特定警告
import { LogBox } from 'react-native';
LogBox.ignoreLogs(['Warning: ...']);
```

### 10. OTA 热更新 — EAS Update (Expo)

```bash
# 安装 EAS CLI
npm install -g eas-cli

# 配置 eas.json
# {
#   "build": {
#     "production": { "autoIncrement": true }
#   },
#   "update": {
#     "url": "https://u.expo.dev/your-project-id"
#   }
# }

# 发布 OTA 更新（不经过 App Store 审核）
eas update --branch production --message "修复登录 Bug"

# 用户下次打开 App 自动拉取更新
# 代码中检查更新
import * as Updates from 'expo-updates';

async function checkForUpdates() {
  try {
    const update = await Updates.checkForUpdateAsync();
    if (update.isAvailable) {
      await Updates.fetchUpdateAsync();
      await Updates.reloadAsync();  // 热重载
    }
  } catch (e) {
    console.log('Update check failed:', e);
  }
}
```

### 11. 动画系统

```tsx
// Reanimated — 高性能动画（推荐）
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from 'react-native-reanimated';

function AnimatedCard() {
  const offset = useSharedValue(0);
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: offset.value },
      { scale: scale.value },
    ],
  }));

  return (
    <Animated.View style={[styles.card, animatedStyle]}>
      <TouchableOpacity
        onPressIn={() => { scale.value = withSpring(0.95); }}
        onPressOut={() => {
          scale.value = withSpring(1);
          offset.value = withSpring(offset.value + 20);
        }}
      >
        <Text>Press Me</Text>
      </TouchableOpacity>
    </Animated.View>
  );
}

// Layout Animation — 布局动画
import { Layout } from 'react-native-reanimated';

<Animated.View
  layout={Layout.springify()}
  entering={FadeInDown.duration(300)}
  exiting={FadeOutUp.duration(200)}
>
  <Text>Animated Content</Text>
</Animated.View>
```

## Common Patterns

### 1. 认证流程

```tsx
// Auth Context
const AuthContext = createContext<AuthContextType | null>(null);

function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // 启动时检查 Token
    AsyncStorage.getItem('token').then((token) => {
      if (token) {
        api.get('/me').then(({ data }) => setUser(data)).finally(() => setIsLoading(false));
      } else {
        setIsLoading(false);
      }
    });
  }, []);

  const login = async (email: string, password: string) => {
    const { user, token } = await authService.login(email, password);
    await AsyncStorage.setItem('token', token);
    setUser(user);
  };

  const logout = async () => {
    await AsyncStorage.removeItem('token');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, isLoading }}>
      {children}
    </AuthContext.Provider>
  );
}

// 根组件
function App() {
  return (
    <AuthProvider>
      <NavigationContainer>
        <RootNavigator />
      </NavigationContainer>
    </AuthProvider>
  );
}

// 根据登录状态切换导航
function RootNavigator() {
  const { user, isLoading } = useAuth();
  if (isLoading) return <SplashScreen />;
  return user ? <MainStack /> : <AuthStack />;
}
```

### 2. 错误边界

```tsx
import { Component, ReactNode } from 'react';

interface Props { children: ReactNode; fallback: ReactNode; }
interface State { hasError: boolean; }

class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('ErrorBoundary caught:', error, info);
    // 上报到 Sentry / Bugsnag
  }

  render() {
    if (this.state.hasError) return this.props.fallback;
    return this.props.children;
  }
}

// 使用
<ErrorBoundary fallback={<ErrorScreen onRetry={() => {}} />}>
  <App />
</ErrorBoundary>
```

### 3. 平台特定代码

```tsx
import { Platform, StyleSheet } from 'react-native';

// Platform.select
const styles = StyleSheet.create({
  container: {
    ...Platform.select({
      ios: { shadowColor: '#000', shadowOpacity: 0.1, shadowRadius: 4 },
      android: { elevation: 3 },
    }),
  },
});

// Platform.OS
if (Platform.OS === 'ios') {
  // iOS 特定逻辑
}

// 平台特定文件
// Button.ios.tsx  ← iOS 使用
// Button.android.tsx  ← Android 使用
// import Button from './Button';  ← 自动选择
```

### 4. 推送通知

```tsx
import * as Notifications from 'expo-notifications';

// 请求权限
async function registerForPushNotifications() {
  const { status } = await Notifications.requestPermissionsAsync();
  if (status !== 'granted') return null;

  const token = await Notifications.getExpoPushTokenAsync({
    projectId: 'your-project-id',
  });
  return token.data;
}

// 监听通知
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

// 前台监听
useEffect(() => {
  const sub = Notifications.addNotificationReceivedListener((notification) => {
    console.log('Received:', notification.request.content);
  });
  return () => sub.remove();
}, []);

// 点击通知
useEffect(() => {
  const sub = Notifications.addNotificationResponseReceivedListener((response) => {
    const { screen, id } = response.notification.request.content.data;
    router.push(`/${screen}/${id}`);
  });
  return () => sub.remove();
}, []);
```

## References

- [React Native 官方文档](https://reactnative.dev/)
- [Expo 文档](https://docs.expo.dev/)
- [React Navigation 文档](https://reactnavigation.org/)
- [Expo Router 文档](https://docs.expo.dev/router/introduction/)
- [Zustand 文档](https://zustand-demo.pmnd.rs/)
- [Redux Toolkit 文档](https://redux-toolkit.js.org/)
- [React Native Reanimated](https://docs.swmansion.com/react-native-reanimated/)
- [React Native MMKV](https://github.com/mrousavy/react-native-mmkv)
- [EAS Update 文档](https://docs.expo.dev/eas-update/introduction/)
- [Expo Notifications](https://docs.expo.dev/push-notifications/overview/)
- [React Native Directory — 组件库](https://reactnative.directory/)
