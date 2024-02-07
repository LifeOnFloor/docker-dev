# 使い方

** macOSの場合 **
1. ターミナルで`./setup_laravel.sh`を実行する。
2. `laravel/config/`の各ファイルに追記
    ```database.php
    # laravel/config/database.php
    'connections' => [
    'mongodb' => [
            'driver' => 'mongodb',
            'dsn' => env('DB_URI', 'mongodb+srv://username:password@<atlas-cluster-uri>/myappdb?retryWrites=true&w=majority'),
            'database' => 'myappdb',
    ],
    ```
    ```database.php
    # laravel/config/database.php
    'default' => env('DB_CONNECTION', 'mongodb'),
    ```
    ```app.php
    # laravel/config/app.php
    'providers' => [

    /*
    * Laravel Framework Service Providers...
    */

    MongoDB\Laravel\MongoDBServiceProvider::class,
    ```