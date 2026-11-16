<?php

namespace App\Services;

use App\Models\Elderly;
use App\Models\EmergencyLog;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GeminiService
{
    protected string $apiKey;
    protected string $model;

    public function __construct()
    {
        $this->apiKey = env('GEMINI_API_KEY', '');
        $this->model = env('GEMINI_MODEL', 'gemini-1.5-flash');
    }

    /**
     * معالجة سؤال المستخدم ودمجه بسياق المريض الفعلي
     */
    public function ask(?int $elderlyId, string $userMessage): array
    {
        $userMessage = trim($userMessage);
        if (empty($userMessage)) {
            return [
                'status' => 'error',
                'message' => 'يرجى تقديم نص الاستفسار',
            ];
        }

        // 1. الكشف المسبق عن حالات الاستغاثة والطوارئ المباشرة أولاً لأمان المريض
        $isEmergency = $this->detectEmergencyKeywords($userMessage);

        // إذا كانت استغاثة واضحة وكبير السن معروف، نسجل بلاغ طوارئ حقيقي في emergency_log فوراً
        $createdEmergencyId = null;
        if ($isEmergency && $elderlyId) {
            try {
                $emergency = EmergencyLog::create([
                    'E_Time' => now()->format('H:i:s'),
                    'E_Date' => now()->format('Y-m-d'),
                    'E_Location' => 'استغاثة فورية عبر المساعد الصوتي',
                    'E_State' => 'نشط',
                    'Descripion' => "نداء استغاثة صوتي: {$userMessage}",
                    'Elderly_ID' => $elderlyId,
                ]);
                $createdEmergencyId = $emergency->Emergency_ID;
            } catch (\Throwable $e) {
                Log::error('فشل تسجيل بلاغ الطوارئ التلقائي: ' . $e->getMessage());
            }
        }

        // 2. التحقق من مفتاح API
        if (empty($this->apiKey)) {
            if ($isEmergency) {
                return [
                    'status' => 'success',
                    'reply' => 'تم رصد نداء الاستغاثة فوراً وتسجيل بلاغ طوارئ وإخطار مقدم الرعاية. يرجى التزام الهدوء، المساعدة في طريقها إليك.',
                    'is_emergency' => true,
                    'emergency_id' => $createdEmergencyId,
                ];
            }

            return [
                'status' => 'error',
                'message' => 'مفتاح Gemini API غير مهيأ في الخادم (يرجى إضافته في ملف backend/.env: GEMINI_API_KEY)',
            ];
        }

        // 3. جمع سياق المريض الفعلي من MySQL
        $context = $this->buildPatientContext($elderlyId);

        // 4. بناء الـ System Prompt المتخصص
        $systemInstruction = "أنت 'يُسر'، المساعد الصوتي والذكاء الاصطناعي الذكي في تطبيق يُسر (Yusr) لرعاية كبار السن.
مهمتك: مساعدة كبير السن ومقدم الرعاية والإجابة بدقة ودفء واحترام باللغة العربية.
قواعد صارمة لا يمكن مخالفتها:
1. اعتمد فقط على بيانات المريض الفعلية المرفقة في السياق (الأدوية، المواعيد، القياسات الصحية).
2. لا تختلق أي مواعيد أو أدوية أو قراءات غير موجودة في السياق.
3. ممنوع منعاً باتاً وصف أدوية جديدة أو تعديل الجرعات الطبية أو تقديم تشخيصات طبية قاطعة، ووجه المريض دائماً لاستشارة طبيبه المعالج.
4. إذا طلب المريض المساعدة العاجلة أو الطوارئ أو اشتكى من سقوط أو ألم شديد بالصدر، طمئنه وأكد له أنه تم تفعيل نداء الطوارئ وسيتم إخطار مقدم الرعاية فوراً، وانصحه بالهدوء.
5. اجعل الإجابة مختصرة وواضحة وسلسة ومناسبة للنطق الصوتي (TTS) بدون رموز معقدة أو روابط غير ضرورية.";

        $promptWithContext = "سياق المريض الفعلي المسجل في قاعدة البيانات:\n" .
            $context . "\n\n" .
            "سؤال المستخدم:\n" . $userMessage;

        // 5. استدعاء Gemini API عبر HTTP
        try {
            $sslVerify = filter_var(env('GEMINI_SSL_VERIFY', true), FILTER_VALIDATE_BOOLEAN);

            $response = Http::withOptions(['verify' => $sslVerify])
                ->timeout(25)
                ->post($url, [
                'system_instruction' => [
                    'parts' => [
                        ['text' => $systemInstruction]
                    ]
                ],
                'contents' => [
                    [
                        'role' => 'user',
                        'parts' => [
                            ['text' => $promptWithContext]
                        ]
                    ]
                ],
                'generationConfig' => [
                    'temperature' => 0.4,
                    'maxOutputTokens' => 500,
                ]
            ]);

            if ($response->successful()) {
                $data = $response->json();
                $replyText = $data['candidates'][0]['content']['parts'][0]['text'] ?? 'أنا هنا لمساعدتك دائماً في تطبيق يسر.';

                return [
                    'status' => 'success',
                    'reply' => trim($replyText),
                    'is_emergency' => $isEmergency,
                    'emergency_id' => $createdEmergencyId,
                ];
            } else {
                $errorMsg = $response->json()['error']['message'] ?? 'فشل الاتصال بـ Gemini API';
                Log::error('Gemini API Error: ' . $errorMsg);
                return [
                    'status' => 'error',
                    'message' => 'عذراً، حدث خطأ أثناء التواصل مع المساعد الذكي: ' . $errorMsg,
                ];
            }
        } catch (\Throwable $e) {
            Log::error('Gemini Exception: ' . $e->getMessage());
            return [
                'status' => 'error',
                'message' => 'تعذر الاتصال بخدمة الذكاء الاصطناعي: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * استخراج وتجهيز بيانات كبير السن الحالية من قاعدة البيانات
     */
    protected function buildPatientContext(?int $elderlyId): string
    {
        if (!$elderlyId) {
            return "المستخدم لم يحدد ملف كبير سن معين حالياً.";
        }

        $elderly = Elderly::with([
            'medications',
            'appointments',
            'healthRecords' => function ($q) {
                $q->orderBy('H_Record_ID', 'desc')->limit(3);
            },
            'emergencyContacts',
            'emergencyLogs' => function ($q) {
                $q->orderBy('Emergency_ID', 'desc')->limit(2);
            }
        ])->find($elderlyId);

        if (!$elderly) {
            return "كبير السن برقم ({$elderlyId}) غير موجود في قاعدة البيانات.";
        }

        $ctx = "اسم كبير السن: {$elderly->E_Name} (الجنس: {$elderly->E_sex})\n";

        // الأدوية
        $ctx .= "قائمة الأدوية المعتمدة:\n";
        if ($elderly->medications->isEmpty()) {
            $ctx .= "- لا توجد أدوية مسجلة حالياً.\n";
        } else {
            foreach ($elderly->medications as $m) {
                $ctx .= "- دواء: {$m->M_Name} | الجرعة: {$m->M_much} | التكرار: {$m->M_RepatTime}\n";
            }
        }

        // المواعيد
        $ctx .= "المواعيد الطبية القادمة:\n";
        if ($elderly->appointments->isEmpty()) {
            $ctx .= "- لا توجد مواعيد مسجلة حالياً.\n";
        } else {
            foreach ($elderly->appointments as $a) {
                $ctx .= "- موعد: {$a->A_DateType} | التاريخ: {$a->A_Date} | الوقت: {$a->A_Time} | المكان: {$a->A_Location} | ملاحظات: {$a->A_Note}\n";
            }
        }

        // آخر القراءات الصحية
        $ctx .= "آخر القياسات الصحية المسجلة:\n";
        if ($elderly->healthRecords->isEmpty()) {
            $ctx .= "- لا توجد قراءات صحية سابقة.\n";
        } else {
            foreach ($elderly->healthRecords as $h) {
                $ctx .= "- التاريخ: {$h->H_Date} | النبض: {$h->Heart_Rate} | الضغط: {$h->Blood_pressure} | الأكسجين: {$h->Oxyger}% | الحرارة: {$h->Temperature}°C | الخطوات: {$h->steps}\n";
            }
        }

        // جهات اتصال الطوارئ
        $ctx .= "جهات اتصال الطوارئ:\n";
        if ($elderly->emergencyContacts->isEmpty()) {
            $ctx .= "- لم يتم تسجيل جهات طوارئ عائلية بعد.\n";
        } else {
            foreach ($elderly->emergencyContacts as $c) {
                $ctx .= "- {$c->contact_Name} ({$c->Relationship}): {$c->Phone_Number}\n";
            }
        }

        return $ctx;
    }

    /**
     * رصد كلمات الاستغاثة والأعراض الحرجة
     */
    protected function detectEmergencyKeywords(string $text): bool
    {
        $keywords = [
            'طوارئ', 'اسعاف', 'إسعاف', 'نجدة', 'النجدة', 'ساعدوني', 'الحقوني',
            'سقطت', 'طحت', 'وقعت', 'دايخ', 'أغمي', 'فقدت الوعي', 'ألم في الصدر',
            'ألم شديد', 'تعبان جدا', 'مش قادر اتنفس', 'صعوبة تنفس', 'اختناق'
        ];

        foreach ($keywords as $kw) {
            if (mb_stripos($text, $kw) !== false) {
                return true;
            }
        }

        return false;
    }
}
