---
name: flutter
description: Flutter 跨平台移动应用开发技能。覆盖 Flutter SDK、Dart 语言、Widget 体系、状态管理（Riverpod/Bloc/GetX）、路由、网络请求、本地存储、平台通道、性能优化及发布流程。适用于 iOS/Android/Web/Desktop 多端应用开发。
---

# Flutter 跨平台开发

## When to Use This Skill

- 用户需要构建跨平台移动应用（iOS + Android + Web + Desktop）
- 使用 Dart 语言和 Flutter SDK 进行开发
- 涉及 Widget 组合、状态管理、路由导航、网络请求、本地存储等
- 需要平台特定功能（相机、GPS、传感器等）通过 Platform Channel 集成
- 需要优化 Flutter 应用性能（渲染、内存、包体积）
- 准备发布到 App Store / Google Play / Web

## Not For / Boundaries

- **不适用于**原生 iOS (Swift/ObjC) 或原生 Android (Kotlin/Java) 纯原生开发
- **不适用于**Flutter 嵌入原生视图的深度定制场景（复杂原生 UI 混合）
- **不涵盖**Flutter Engine 层 C++ 开发
- **不替代**专业 UI/UX 设计工具（Figma/Sketch）
- 对于简单的 Web 页面，Flutter Web 不是最佳选择，建议使用前端框架

## Quick Reference

### 1. 项目结构

```
lib/
├── main.dart                  # 入口文件
├── app.dart                   # MaterialApp 配置
├── config/                    # 配置（主题、路由、环境变量）
│   ├── theme.dart
│   ├── routes.dart
│   └── env.dart
├── core/                      # 核心工具（网络、存储、工具类）
│   ├── network/
│   │   ├── api_client.dart
│   │   └── interceptors.dart
│   ├── storage/
│   │   └── local_storage.dart
│   └── utils/
│       └── logger.dart
├── features/                  # 功能模块（按领域划分）
│   ├── auth/
│   │   ├── data/              # 数据层（Repository、Model、DataSource）
│   │   ├── domain/            # 领域层（Entity、UseCase）
│   │   └── presentation/      # 表现层（Page、Widget、Controller）
│   ├── home/
│   └── profile/
├── shared/                    # 共享组件
│   ├── widgets/
│   └── extensions/
└── gen/                       # 自动生成（l10n、assets）
```

### 2. 入口文件与基础配置

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(  // Riverpod 状态管理注入
      child: MyApp(),
    ),
  );
}

// lib/app.dart
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'My App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,  // GoRouter 配置
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### 3. Widget 常用模式

#### StatelessWidget vs StatefulWidget

```dart
// StatelessWidget — 无状态，纯展示
class UserCard extends StatelessWidget {
  final String name;
  final String avatar;
  
  const UserCard({super.key, required this.name, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundImage: NetworkImage(avatar)),
        title: Text(name, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

// StatefulWidget — 有状态，交互
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('$_count', style: const TextStyle(fontSize: 48))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

#### 常用布局 Widget

```dart
// Row / Column — 线性布局
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text('标题'),
    Icon(Icons.arrow_forward),
  ],
)

// Stack — 层叠布局
Stack(
  children: [
    Image.network(url, fit: BoxFit.cover),
    Positioned(
      bottom: 8, left: 8,
      child: Text('叠加文字', style: TextStyle(color: Colors.white)),
    ),
  ],
)

// ListView.builder — 高性能列表（懒加载）
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return ListTile(title: Text(item.title));
  },
)

// GridView — 网格布局
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  ),
  itemCount: products.length,
  itemBuilder: (context, index) => ProductCard(product: products[index]),
)
```

### 4. 状态管理选型

#### Riverpod（推荐 — 现代、类型安全、可测试）

```dart
// 定义 Provider
final counterProvider = StateNotifierProvider<CounterNotifier, int>((ref) {
  return CounterNotifier();
});

class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);
  void increment() => state++;
  void decrement() => state--;
}

// 异步数据 Provider
final userProvider = FutureProvider<User>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getCurrentUser();
});

// 在 Widget 中使用
class CounterPage extends ConsumerWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      body: Column(
        children: [
          Text('$count'),
          userAsync.when(
            data: (user) => Text('Hello, ${user.name}'),
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Text('Error: $err'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(counterProvider.notifier).increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

#### Bloc（适合大型团队、严格分层）

```dart
// Event
abstract class CounterEvent {}
class CounterIncremented extends CounterEvent {}
class CounterDecremented extends CounterEvent {}

// Bloc
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<CounterIncremented>((event, emit) => emit(state + 1));
    on<CounterDecremented>((event, emit) => emit(state - 1));
  }
}

// 使用
BlocProvider(
  create: (_) => CounterBloc(),
  child: BlocBuilder<CounterBloc, int>(
    builder: (context, count) => Text('$count'),
  ),
)
```

#### GetX（轻量快速、适合小项目）

```dart
// Controller
class CounterController extends GetxController {
  final count = 0.obs;
  void increment() => count++;
}

// 使用
final c = Get.put(CounterController());
Obx(() => Text('${c.count}'));
```

### 5. 路由导航 — GoRouter

```dart
// lib/config/routes.dart
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/product/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProductPage(productId: id);
      },
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/explore', builder: (_, __) => const ExplorePage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
  ],
  redirect: (context, state) {
    final isLoggedIn = /* check auth */;
    if (!isLoggedIn && state.matchedLocation != '/login') {
      return '/login';
    }
    return null;
  },
);

// 导航
context.go('/product/123');          // 替换导航
context.push('/product/123');        // 压入导航栈
context.pop();                       // 返回
```

### 6. 网络请求 — Dio

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? 'https://api.example.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 注入 Token
          final token = StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token 过期，刷新或跳转登录
          }
          handler.next(error);
        },
      ),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) =>
      _dio.get<T>(path, queryParameters: params);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);
}

// 使用示例
class UserRepository {
  final ApiClient _api;
  UserRepository(this._api);

  Future<User> getUser(String id) async {
    final response = await _api.get('/users/$id');
    return User.fromJson(response.data);
  }

  Future<List<User>> getUsers({int page = 1}) async {
    final response = await _api.get('/users', params: {'page': page});
    return (response.data['data'] as List)
        .map((e) => User.fromJson(e))
        .toList();
  }
}
```

### 7. 本地存储

```dart
// SharedPreferences — 简单键值对
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? getString(String key) => _prefs.getString(key);
  static Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  static String? getToken() => getString('auth_token');
}

// Hive — 高性能 NoSQL（适合复杂对象）
import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String email;

  User({required this.name, required this.email});
}

// 初始化
await Hive.initFlutter();
Hive.registerAdapter(UserAdapter());
final box = await Hive.openBox<User>('users');
box.put('current', User(name: 'John', email: 'john@example.com'));

// SQLite — 关系型数据（sqflite）
import 'package:sqflite/sqflite.dart';

final db = await openDatabase(
  'my_app.db',
  version: 1,
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL
      )
    ''');
  },
);

await db.insert('users', {'name': 'John', 'email': 'john@example.com'});
final users = await db.query('users', where: 'name = ?', whereArgs: ['John']);
```

### 8. Platform Channel — 平台原生通信

```dart
// Dart 端
import 'package:flutter/services.dart';

class BatteryService {
  static const _channel = MethodChannel('com.example/battery');

  static Future<int> getBatteryLevel() async {
    final level = await _channel.invokeMethod<int>('getBatteryLevel');
    return level ?? -1;
  }
}

// Android 端 (Kotlin)
// MainActivity.kt
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example/battery")
            .setMethodCallHandler { call, result ->
                if (call.method == "getBatteryLevel") {
                    val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
                    val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    result.success(level)
                } else {
                    result.notImplemented()
                }
            }
    }
}

// iOS 端 (Swift)
// AppDelegate.swift
@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "com.example/battery",
                                            binaryMessenger: controller.binaryMessenger)
        channel.setMethodCallHandler { (call, result) in
            if call.method == "getBatteryLevel" {
                UIDevice.current.isBatteryMonitoringEnabled = true
                let level = Int(UIDevice.current.batteryLevel * 100)
                result(level)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### 9. 常用 Widget 组件模板

```dart
// 自定义按钮
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(text),
      ),
    );
  }
}

// 下拉刷新 + 上拉加载更多
class PaginatedList<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) fetchPage;
  final Widget Function(T item) itemBuilder;

  const PaginatedList({super.key, required this.fetchPage, required this.itemBuilder});

  @override
  State<PaginatedList<T>> createState() => _PaginatedListState<T>();
}

class _PaginatedListState<T> extends State<PaginatedList<T>> {
  final List<T> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    final newItems = await widget.fetchPage(_page);
    setState(() {
      _items.addAll(newItems);
      _page++;
      _hasMore = newItems.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _items.clear(); _page = 1; _hasMore = true; });
        await _loadMore();
      },
      child: ListView.builder(
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            _loadMore();
            return const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ));
          }
          return widget.itemBuilder(_items[index]);
        },
      ),
    );
  }
}
```

### 10. 性能优化

```dart
// 1. 使用 const 构造函数减少重建
const Text('Hello');  // ✅ const
Text('Hello');        // ❌ 每次 build 都重建

// 2. 使用 ListView.builder 而非 ListView（懒加载）
ListView.builder(itemBuilder: (ctx, i) => ItemWidget(items[i]));

// 3. 避免在 build 中创建对象
// ❌ 错误
Widget build(context) {
  final style = TextStyle(fontSize: 16);  // 每次 build 都创建
  return Text('Hello', style: style);
}
// ✅ 正确
static const _style = TextStyle(fontSize: 16);

// 4. RepaintBoundary 隔离重绘区域
RepaintBoundary(
  child: ComplexWidget(),  // 复杂动画或图表
)

// 5. 使用 AutomaticKeepAliveClientMixin 保持 Tab 页状态
class TabPage extends StatefulWidget with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  // ...
}

// 6. 图片优化 — cached_network_image
CachedNetworkImage(
  imageUrl: url,
  placeholder: (_, __) => const CircularProgressIndicator(),
  errorWidget: (_, __, ___) => const Icon(Icons.error),
  memCacheWidth: 300,  // 限制内存缓存尺寸
)
```

### 11. 发布流程

```bash
# Android
flutter build appbundle --release          # 生成 AAB（Google Play）
flutter build apk --release                # 生成 APK
# 输出: build/app/outputs/bundle/release/app-release.aab

# iOS
flutter build ipa --release                # 生成 IPA
# 需要 Apple Developer 证书 + Provisioning Profile
# 输出: build/ios/ipa/

# Web
flutter build web --release --web-renderer canvaskit
# 输出: build/web/

# 版本管理 — pubspec.yaml
# version: 1.2.3+45  （版本名 + 构建号）
```

## Common Patterns

### 1. Clean Architecture 分层

```
Presentation (UI) → Domain (UseCase) → Data (Repository)
     ↑                    ↑                    ↑
   Widget/Controller    Entity/Interface    API/DB/Cache
```

### 2. 表单验证

```dart
final _formKey = GlobalKey<FormState>();

Form(
  key: _formKey,
  child: Column(
    children: [
      TextFormField(
        validator: (value) {
          if (value == null || value.isEmpty) return '请输入邮箱';
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return '邮箱格式不正确';
          }
          return null;
        },
      ),
      ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            // 提交表单
          }
        },
        child: const Text('提交'),
      ),
    ],
  ),
)
```

### 3. 主题与国际化

```dart
// 主题
class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
    brightness: Brightness.light,
  );
  static final dark = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.blue,
    brightness: Brightness.dark,
  );
}

// 国际化 — 使用 flutter_localizations + intl
// l10n.yaml
// arb-dir: lib/l10n
// template-arb-file: app_en.arb
// output-localization-file: app_localizations.dart

// app_en.arb
// { "hello": "Hello", "@hello": { "description": "A greeting" } }
// app_zh.arb
// { "hello": "你好" }

// 使用
Text(AppLocalizations.of(context)!.hello)
```

### 4. 错误处理与 Loading 状态封装

```dart
sealed class AsyncState<T> {
  const AsyncState();
}

class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();
}

class AsyncSuccess<T> extends AsyncState<T> {
  final T data;
  const AsyncSuccess(this.data);
}

class AsyncError<T> extends AsyncState<T> {
  final String message;
  const AsyncError(this.message);
}

// Widget 中使用
Widget build(BuildContext context) {
  return switch (state) {
    AsyncLoading() => const CircularProgressIndicator(),
    AsyncSuccess(data: final user) => Text(user.name),
    AsyncError(message: final msg) => Text('Error: $msg'),
  };
}
```

## References

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言文档](https://dart.dev/language)
- [Flutter API 参考](https://api.flutter.dev/)
- [Riverpod 官方文档](https://riverpod.dev/)
- [Bloc 官方文档](https://bloclibrary.dev/)
- [GetX 文档](https://pub.dev/packages/get)
- [GoRouter 文档](https://pub.dev/packages/go_router)
- [Dio 文档](https://pub.dev/packages/dio)
- [pub.dev — Flutter/Dart 包仓库](https://pub.dev/)
- [Flutter Widget 目录](https://docs.flutter.dev/ui/widgets)
- [Flutter 性能最佳实践](https://docs.flutter.dev/perf/best-practices)
