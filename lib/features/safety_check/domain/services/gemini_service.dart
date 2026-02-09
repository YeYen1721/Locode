import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../data/models/safety_result_model.dart';

/// Service responsible for multimodal security analysis using Gemini 3 Flash.
class GeminiService {
  final GenerativeModel _model;

  GeminiService(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-3-flash-preview',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

  /// Analyzes a [url] and optional [imageBytes] using multimodal context.
  /// 
  /// The logic prioritizes Savannah, GA security patterns but is globally extensible.
  /// Uses [compute] for JSON decoding to maintain 120Hz UI performance.
  Future<LocodeResult> analyzeSafety({
    required String url,
    required double latitude,
    required double longitude,
    Uint8List? imageBytes,
  }) async {
    final prompt = '''
      SYSTEM: You are the Locode Security Agent in Savannah, GA.
      TASK: Perform a MULTIMODAL CONTEXT AUDIT. Compare physical evidence with digital links.
      
      CONTEXT:
      - User Location: ($latitude, $longitude)
      - Digital URL: $url
      
      SECURITY AUDIT LOGIC (High Priority):
      1. CRITICAL DISCREPANCY: Analyze text/branding in the attached image. If the image shows "City of Savannah", "Official Parking", or local government logos, but the URL domain is NOT an official .gov or trusted payment portal (e.g., uses .cc, .xyz, or strange subdomains), return status "Danger" with "Critical Discrepancy" in the reasoning.
      2. LOOKALIKE AUDIT: Check if the URL is trying to mimic "parkmobile" or "passport" but with typos.
      3. HTML INTENT: Assume the URL leads to a payment portal. If the physical location is a remote park but the URL is for a high-density garage, flag as Warning.
      
      OUTPUT:
      Return JSON: {"status": "Safe" | "Danger" | "Warning", "risk_score": 0-100, "reasoning": "string"}
    ''';

    final List<Content> content = [
      Content.multi([
        TextPart(prompt),
        if (imageBytes != null) DataPart('image/jpeg', imageBytes),
      ])
    ];

    GenerateContentResponse? response;
    
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        response = await _model.generateContent(content).timeout(const Duration(seconds: 15));
        break; // Success
      } on SocketException catch (e) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          return LocodeResult(
            status: 'Danger',
            riskScore: 99,
            reasoning: 'Unable to reach analysis service. Check your connection.',
          );
        }
      } on TimeoutException catch (e) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          return LocodeResult(
            status: 'Danger',
            riskScore: 99,
            reasoning: 'Analysis timed out. Check your connection.',
          );
        }
      } catch (e) {
        return LocodeResult(
          status: 'Danger',
          riskScore: 99,
          reasoning: 'Multimodal guard failed: $e',
        );
      }
    }

    if (response == null || response.text == null) {
      return LocodeResult(
        status: 'Danger',
        riskScore: 99,
        reasoning: 'Empty Gemini response after analysis.',
      );
    }

    try {
      return await compute(_parseResult, response.text!);
    } catch (e) {
      return LocodeResult(
        status: 'Danger',
        riskScore: 99,
        reasoning: 'Failed to parse analysis result: $e',
      );
    }
  }

  /// Static helper for [compute] parsing.
  static LocodeResult _parseResult(String text) {
    final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
    return LocodeResult.fromJson(jsonDecode(cleanJson));
  }
}
