<?php
/**
 * ملف الاتصال بقاعدة البيانات المحلية MySQL/phpMyAdmin
 * اسم قاعدة البيانات: yusr_application
 * اسم المستخدم: root (بدون كلمة سر)
 * يدعم استقبال الاتصالات من أي جهاز أو شبكة (CORS مفتوح بالكامل)
 */

if (!headers_sent()) {
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin');
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$dbname = 'yusr_application';
$username = 'root';
$password = '';
$charset = 'utf8mb4';

// تجربة الاتصال عبر localhost ثم 127.0.0.1 لضمان التوافق مع كافة بيئات العمل
$hosts = ['localhost', '127.0.0.1'];
$pdo = null;
$lastException = null;

$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

foreach ($hosts as $host) {
    try {
        $dsn = "mysql:host=$host;dbname=$dbname;charset=$charset";
        $pdo = new PDO($dsn, $username, $password, $options);
        break; // تم الاتصال بنجاح
    } catch (PDOException $e) {
        $lastException = $e;
    }
}

if (!$pdo) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'فشل الاتصال بقاعدة البيانات: ' . ($lastException ? $lastException->getMessage() : 'تعذر الوصول لخادم MySQL'),
        'hint' => 'تأكد من تشغيل خادم MySQL في لوحة تحكم XAMPP'
    ], JSON_UNESCAPED_UNICODE);
    exit;
}
