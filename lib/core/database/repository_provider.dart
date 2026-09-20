import '../../data/repositories/custom_category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import 'database_provider.dart';

final TransactionRepository transactionRepository =
    TransactionRepository(appDatabase);

final CustomCategoryRepository customCategoryRepository =
    CustomCategoryRepository(appDatabase);