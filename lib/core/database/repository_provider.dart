import '../../data/repositories/transaction_repository.dart';
import 'database_provider.dart';

final TransactionRepository transactionRepository =
    TransactionRepository(appDatabase);