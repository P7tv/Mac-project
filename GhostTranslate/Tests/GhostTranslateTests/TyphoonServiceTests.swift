import XCTest
@testable import GhostTranslateCore

final class TyphoonServiceTests: XCTestCase {
    func testRequestPayloadEncoding() throws {
        let request = TyphoonRequest(
            model: "typhoon-v2.5-30b-a3b-instruct",
            messages: [
                TyphoonMessage(role: "system", content: "You are a translator."),
                TyphoonMessage(role: "user", content: "Hello world")
            ],
            maxTokens: 100,
            temperature: 0.3
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "typhoon-v2.5-30b-a3b-instruct")
        XCTAssertEqual(json?["max_tokens"] as? Int, 100)
    }

    func testResponseParsing() throws {
        let jsonString = """
        {
            "id": "chatcmpl-test",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "สวัสดีชาวโลก"}
            }]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(TyphoonResponse.self, from: data)
        XCTAssertEqual(response.choices.first?.message.content, "สวัสดีชาวโลก")
    }

    func testInterviewPromptsParsing() {
        let sampleMarkdown = """
        **สรุปคำถาม:** ทำไมเราควรจ้างคุณ?
        - ข้อที่ 1: ดึงจุดเด่นตรงกับงาน
        - ข้อที่ 2: ยกตัวอย่างผลงานวัดได้
        - ข้อที่ 3: แสดงความมุ่งมั่น
        """
        let structured = Prompts.parseInterviewResponse(sampleMarkdown)
        XCTAssertFalse(structured.questionSummary.isEmpty)
        XCTAssertEqual(structured.bulletPoints.count, 3)
    }
}
