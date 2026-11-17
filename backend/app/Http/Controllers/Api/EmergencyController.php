<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use App\Models\EmergencyLog;
use Illuminate\Http\Request;

class EmergencyController extends Controller
{
    /**
     * ط³ط¬ظ„ ط¨ظ„ط§ط؛ط§طھ ط§ظ„ط·ظˆط§ط±ط¦
     */
    public function getLogs(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = EmergencyLog::with('elderly');
        if ($elderlyId) {
            $query->where('Elderly_ID', $elderlyId);
        }

        $logs = $query->orderBy('Emergency_ID', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $logs
        ]);
    }

    /**
     * ط¥ط±ط³ط§ظ„ ط¨ظ„ط§ط؛ ط·ظˆط§ط±ط¦ ط¬ط¯ظٹط¯
     */
    public function storeLog(Request $request)
    {
        $elderlyId = $request->input('Elderly_ID');
        $type = $request->input('E_Type');
        $location = $request->input('E_Location', 'ظ…ظˆظ‚ط¹ ط؛ظٹط± ظ…ط­ط¯ط¯');
        $lat = $request->input('latitude');
        $lng = $request->input('Longitude');
        $desc = $request->input('Descripion', 'ظ†ط¯ط§ط، ط·ظˆط§ط±ط¦ ط¹ط§ط¬ظ„ ظ…ظ† ط§ظ„طھط·ط¨ظٹظ‚');

        $log = EmergencyLog::create([
            'E_Type' => $type,
            'E_Time' => now()->format('H:i:s'),
            'E_Date' => now()->format('Y-m-d'),
            'E_Location' => $location,
            'latitude' => $lat,
            'Longitude' => $lng,
            'E_State' => 'ظ†ط´ط·',
            'Descripion' => $desc,
            'Elderly_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… طھط³ط¬ظٹظ„ ط¨ظ„ط§ط؛ ط§ظ„ط·ظˆط§ط±ط¦ ط¨ظ†ط¬ط§ط­ ظˆط¥ط±ط³ط§ظ„ظ‡ ظپظˆط±ط§ظ‹ ظ„ظ…ظ‚ط¯ظ… ط§ظ„ط±ط¹ط§ظٹط©',
            'data' => $log
        ], 201);
    }

    /**
     * طھط­ط¯ظٹط« ط­ط§ظ„ط© ط§ظ„ط¨ظ„ط§ط؛ (ظ‚ظٹط¯ ط§ظ„ظ…طھط§ط¨ط¹ط© / طھظ…طھ ط§ظ„ظ…ط¹ط§ظ„ط¬ط©)
     */
    public function updateStatus(Request $request, $id = null)
    {
        $emergencyId = $id ?? $request->input('Emergency_ID');
        $state = trim($request->input('E_State', ''));
        $note = trim($request->input('note', $request->input('Descripion', '')));

        if (!$emergencyId || empty($state)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ظ…ط¹ط±ظپ ط§ظ„ط¨ظ„ط§ط؛ ظˆط­ط§ظ„ط© ط§ظ„ظ…طھط§ط¨ط¹ط© ط§ظ„ط¬ط¯ظٹط¯ط© ظ…ط·ظ„ظˆط¨ط§ظ†'
            ], 200);
        }

        $emergency = EmergencyLog::find($emergencyId);
        if (!$emergency) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط¨ظ„ط§ط؛ ط§ظ„ط·ظˆط§ط±ط¦ ط؛ظٹط± ظ…ظˆط¬ظˆط¯ ظپظٹ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ'
            ], 200);
        }

        $updateData = ['E_State' => $state];
        if (!empty($note)) {
            $currentDesc = (string)$emergency->Descripion;
            $updateData['Descripion'] = $currentDesc . " [ظ…ظ„ط§ط­ط¸ط©: {$note}]";
        }

        $emergency->update($updateData);

        return response()->json([
            'status' => 'success',
            'message' => "طھظ… طھط­ط¯ظٹط« ط­ط§ظ„ط© ط§ظ„ط¨ظ„ط§ط؛ ط¨ظ†ط¬ط§ط­ ط¥ظ„ظ‰: {$state}",
            'data' => $emergency
        ]);
    }

    /**
     * ط¬ظ‡ط§طھ ط§طھطµط§ظ„ ط§ظ„ط·ظˆط§ط±ط¦
     */
    public function getContacts(Request $request)
    {
        $elderlyId = $request->query('elderly_id', $request->query('Elderly_ID', $request->input('elderly_id', $request->input('Elderly_ID'))));

        $query = EmergencyContact::query();
        if ($elderlyId) {
            $query->where('Eldery_ID', $elderlyId);
        }

        $contacts = $query->orderBy('Priority', 'asc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $contacts
        ]);
    }

    public function storeContact(Request $request)
    {
        $name = trim($request->input('contact_Name', ''));
        $phone = trim($request->input('Phone_Number', ''));
        $relationship = trim($request->input('Relationship', ''));
        $priority = $request->input('Priority', 1);
        $elderlyId = $request->input('Eldery_ID', $request->input('Elderly_ID'));

        if (empty($name) || empty($phone)) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط§ط³ظ… ط¬ظ‡ط© ط§ظ„ط§طھطµط§ظ„ ظˆط±ظ‚ظ… ط§ظ„ظ‡ط§طھظپ ظ…ط·ظ„ظˆط¨ط§ظ†'
            ], 200);
        }

        $contact = EmergencyContact::create([
            'contact_Name' => $name,
            'Phone_Number' => $phone,
            'Relationship' => $relationship,
            'Priority' => $priority,
            'Eldery_ID' => $elderlyId,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ…طھ ط¥ط¶ط§ظپط© ط¬ظ‡ط© ط§طھطµط§ظ„ ط§ظ„ط·ظˆط§ط±ط¦ ط¨ظ†ط¬ط§ط­',
            'data' => $contact
        ], 201);
    }

    public function destroyContact($id = null, Request $request = null)
    {
        $contactId = $id ?? ($request ? $request->input('contact_ID') : null);
        $contact = EmergencyContact::find($contactId);

        if (!$contact) {
            return response()->json([
                'status' => 'error',
                'message' => 'ط¬ظ‡ط© ط§ظ„ط§طھطµط§ظ„ ط؛ظٹط± ظ…ظˆط¬ظˆط¯ط©'
            ], 200);
        }

        $contact->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'طھظ… ط­ط°ظپ ط¬ظ‡ط© ط§طھطµط§ظ„ ط§ظ„ط·ظˆط§ط±ط¦ ط¨ظ†ط¬ط§ط­'
        ]);
    }
}

