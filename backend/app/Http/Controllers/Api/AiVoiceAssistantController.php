<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\GeminiService;
use Illuminate\Http\Request;

class AiVoiceAssistantController extends Controller
{
    protected GeminiService $geminiService;

    public function __construct(GeminiService $geminiService)
    {
        $this->geminiService = $geminiService;
    }

    /**
     * استقبال استفسار المساعد الصوتي ومعالجته عبر Gemini API وسياق المريض الفعلي
     */
    public function ask(Request $request)
    {
        $data = $request->all();
        if (empty($data)) {
            $raw = json_decode($request->getContent(), true);
            if (is_array($raw)) {
                $data = $raw;
            }
        }

        $prompt = $data['prompt'] ?? $data['query'] ?? $data['message'] ?? $request->input('prompt', '');
        $elderlyId = $data['elderly_id'] ?? $data['Elderly_ID'] ?? $request->input('elderly_id');

        if (empty(trim((string)$prompt))) {
            return response()->json([
                'status' => 'error',
                'message' => 'يرجى تقديم نص الاستفسار الصوتي أو الكتابي'
            ], 400);
        }

        $result = $this->geminiService->ask($elderlyId ? (int)$elderlyId : null, $prompt);

        return response()->json($result);
    }
}
