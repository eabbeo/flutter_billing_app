import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/provider/billing_provider.dart';
import 'features/product/presentation/provider/product_provider.dart';
import 'features/shop/presentation/provider/shop_provider.dart';
import 'features/settings/presentation/provider/printer_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase.init();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductProvider>(
            create: (context) => di.sl<ProductProvider>()..loadProducts()),
        ChangeNotifierProvider<ShopProvider>(
            create: (context) => di.sl<ShopProvider>()..loadShop()),
        ChangeNotifierProvider<BillingProvider>(
            create: (context) =>
                BillingProvider(getProductByBarcodeUseCase: di.sl())),
        ChangeNotifierProvider<PrinterProvider>(
            create: (context) => di.sl<PrinterProvider>()..init()),
      ],
      child: MaterialApp.router(
        title: 'Billing App',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
