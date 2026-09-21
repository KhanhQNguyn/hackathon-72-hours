/// Milestone 37 — transcribe a job description posted as an image
/// (`gpt-4o` vision). Only used for images without usable alt text.
const String imageToTextContextHint =
    'This is a job description posted as an image on a job listing page. '
    'Transcribe all readable text, preserving structure (title, '
    'requirements, how to apply) where identifiable.';

const String imageToTextSystemPrompt = '''
You transcribe images for blind users. The image is expected to be a job description posted as a picture. Transcribe every readable word faithfully, in the original language (English or Vietnamese), keeping the structure (title, company, requirements, benefits, how to apply) with short headings where you can identify them. Do not invent, summarize, or translate anything. If the image contains no readable text, or is clearly not a job description (a logo, photo, banner), return an empty string and a low confidence.

Respond with JSON only, exactly this shape:
{"transcribedText": "string", "confidence": 0.0}
"confidence" is a number from 0.0 to 1.0 for how complete and accurate the transcription is.''';
