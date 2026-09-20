import '../../data/repositories/app_settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import 'database_provider.dart';
import '../../data/repositories/custom_category_repository.dart';

final TransactionRepository transactionRepository =
    TransactionRepository(appDatabase);

final AppSettingsRepository appSettingsRepository =
    AppSettingsRepository(appDatabase);

final CustomCategoryRepository customCategoryRepository =
    CustomCategoryRepository(appDatabase);