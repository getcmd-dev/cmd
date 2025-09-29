// Test for parseAnthropicResponse tool
// Rather than using execSync which has path resolution issues,
// we'll create a more focused unit test by extracting the function

import { extractTextFromStream } from "./parseAnthropicResponse"

describe("parseAnthropicResponse", () => {
	test("should parse text-only response correctly", () => {
		const input = `event: message_start
data: {"type":"message_start","message":{"id":"msg_018PHAe4Ce6E4FHzJWTzcoXH","type":"message","role":"assistant","model":"claude-3-5-haiku-20241022","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":681,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1,"service_tier":"standard"}}    }

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}              }

event: ping
data: {"type": "ping"}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"none"}  }

event: content_block_stop
data: {"type":"content_block_stop","index":0          }

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":4}              }

event: message_stop
data: {"type":"message_stop"     }`

		const result = extractTextFromStream(input)

		expect(result).toEqual({
			text: "none",
			tools: [],
		})
	})

	test("should parse multiple text deltas correctly", () => {
		const input = `event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" "}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"World"}}`

		const result = extractTextFromStream(input)

		expect(result).toEqual({
			text: "Hello World",
			tools: [],
		})
	})

	test("should parse tool call with partial JSON correctly (old format)", () => {
		const input = `event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"I'll help you with that."}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"partial_json":"{\\"name\\":\\"test_tool\\","}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"partial_json":"\\"parameters\\":{\\"param1\\":\\"value1\\"}}"}}

event: content_block_stop
data: {"type":"content_block_stop","index":1}`

		const result = extractTextFromStream(input)

		expect(result.text).toBe("I'll help you with that.")
		expect(result.tools).toEqual([
			{
				name: "test_tool",
				parameters: {
					param1: "value1",
				},
			},
		])
	})

	test("should parse complete tool call JSON correctly (old format)", () => {
		const input = `event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"partial_json":"{\\"name\\":\\"test_tool\\",\\"parameters\\":{\\"param1\\":\\"value1\\"}}"}}

event: content_block_stop
data: {"type":"content_block_stop","index":1}`

		const result = extractTextFromStream(input)

		expect(result.text).toBe("")
		expect(result.tools).toEqual([
			{
				name: "test_tool",
				parameters: { param1: "value1" },
			},
		])
	})

	test("should handle empty input gracefully", () => {
		const input = ``

		const result = extractTextFromStream(input)

		expect(result).toEqual({
			text: "",
			tools: [],
		})
	})

	test("should handle malformed JSON in tool calls", () => {
		const input = `event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"partial_json":"{\\"incomplete\\":\\"json"}}`

		const result = extractTextFromStream(input)

		expect(result.text).toBe("")
		expect(result.tools).toEqual([
			{
				raw: '{"incomplete":"json',
			},
		])
	})

	test("should skip lines with invalid JSON data", () => {
		const input = `event: content_block_delta
data: invalid json here

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"valid text"}}`

		const result = extractTextFromStream(input)

		expect(result).toEqual({
			text: "valid text",
			tools: [],
		})
	})

	test("should parse Anthropic tool_use format correctly (new format)", () => {
		const input = `event: message_start
data: {"type":"message_start","message":{"id":"msg_01GvGCSfBuw5L5Tx3DcCd1p8","type":"message","role":"assistant","model":"claude-sonnet-4-5-20250929","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":11,"cache_creation_input_tokens":825,"cache_read_input_tokens":45481,"output_tokens":1,"service_tier":"standard"}}     }

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}           }

event: ping
data: {"type": "ping"}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":""}  }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"\\n\\n\\n\\nNow let me run the tests again to see"}      }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":" if we have more issues to fix:"}        }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"EvMBCkYIAxgCKkBDYak8MWbaSLhYkDSp32X3x6JcZ4WLx9bWpJBWz3soCemhipomAzm6cvQzpBc1vGfLeOw7YUVpLwtgoBx9WEtXEgw8ImkQjfkzPPt459waDKs0TiZrLWSFaLYhNCIweNAYm6UAEnywQ0+9gkc7KEseaYS5aaOh7Vbjmdol6P4ZIdvVRYdIqrgM7DKEJev5KluVAy29hsw6hRL1haDKVMjri5RUyI8Mop1f/fTg1ApLOzItX+ZaqjE5WbZMZiN3jKbN2u00B24BqRbcIEhX5ZRAZSal8hKOrZtUWvGE296XVRIULoTZUA8sO9+jGAE="}  }

event: content_block_stop
data: {"type":"content_block_stop","index":0  }

event: content_block_start
data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_01LYYC8wWVZBLVsxFQ7ERp4E","name":"Bash","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":""}              }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"command"}       }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\\": \\"cd /U"}               }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"sers"}            }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"/guigui"}        }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"/dev/"} }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"Xcompan"}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"ion/app/modu"}         }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"les && swi"}     }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"ft test 2>&1"}              }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":" | head -1"}          }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"00\\""}       }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":", \\"descrip"}   }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"tion\\": \\"Run "}     }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"tests ag"}           }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"ain afte"}         }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"r fixing Cha"} }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"tContex"}}

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"t\\"}"}          }

event: content_block_stop
data: {"type":"content_block_stop","index":1             }

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":131}            }

event: message_stop
data: {"type":"message_stop"             }`

		const result = extractTextFromStream(input)

		expect(result.text).toBe("")
		expect(result.tools).toEqual([
			{
				name: "Bash",
				parameters: {
					command: "cd /Users/guigui/dev/Xcompanion/app/modules && swift test 2>&1 | head -100",
					description: "Run tests again after fixing ChatContext",
				},
			},
		])
	})

	test("should parse Anthropic tool_use format correctly (new format)", () => {
		const input = `event: message_start
data: {"type":"message_start","message":{"id":"msg_01PL6rwJ1WrYYMV9iaKLqjvo","type":"message","role":"assistant","model":"claude-sonnet-4-5-20250929","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":8,"cache_creation_input_tokens":369,"cache_read_input_tokens":27639,"output_tokens":33,"service_tier":"standard"}}     }

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_01SbTMMA8keHrNzVv4DPHpbn","name":"Read","input":{}}             }

event: ping
data: {"type": "ping"}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":""}   }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"fil"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"e_path\\": \\"/"} }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"Use"}              }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"rs/gu"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"ig"}         }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"ui/dev/Xcomp"}       }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"anion"}              }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"/app/mo"}    }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"dules/cor"}       }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"eui/"}    }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"CodePreview"}              }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"/Tests/Dif"}   }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"fVie"}           }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"wMode"}               }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"lTe"}          }

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"sts.swift\\"}"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0  }

event: content_block_start
data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_01SsT9a8wUAuvqhaRHYnLfrB","name":"Read","input":{}}      }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":""}    }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"file_path\\""}    }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":": \\"/Users"}     }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"/gu"}              }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"igui/"}          }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"dev/Xco"}     }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"mpanion/app"}   }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"/modules/p"}          }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"lu"}  }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"gins/to"}               }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"ol"}           }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"s/EditFi"}          }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"lesTo"}      }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"ol/Tests/"}            }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"EditFileT"}         }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"ool"}      }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"Tes"} }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"ts.s"}              }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"wif"}    }

event: content_block_delta
data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"t\\"}"}        }

event: content_block_stop
data: {"type":"content_block_stop","index":1          }

event: content_block_start
data: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"toolu_01VZNvkCzUeor3foHivv5B35","name":"Read","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":""}       }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"{\\"fi"}        }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"le_p"}           }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"ath\\": \\"/Us"} }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"ers/guigui/"}    }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"dev/X"}          }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"companion/a"}}

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"pp"}    }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"/mod"}         }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"ul"}     }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"es/foundati"}    }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"ons/SwiftTes"}}

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"ting/So"} }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"urces/Ex"}  }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"pectation.sw"}  }

event: content_block_delta
data: {"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"ift\\"}"}         }

event: content_block_stop
data: {"type":"content_block_stop","index":2 }

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":227}   }

event: message_stop
data: {"type":"message_stop" }

`

		const result = extractTextFromStream(input)

		expect(result.text).toBe("")
		expect(result.tools).toEqual([
			{
				name: "Read",
				parameters: {
					file_path:
						"/Users/guigui/dev/Xcompanion/app/modules/coreui/CodePreview/Tests/DiffViewModelTests.swift",
				},
			},
			{
				name: "Read",
				parameters: {
					file_path:
						"/Users/guigui/dev/Xcompanion/app/modules/plugins/tools/EditFilesTool/Tests/EditFileToolTests.swift",
				},
			},
			{
				name: "Read",
				parameters: {
					file_path:
						"/Users/guigui/dev/Xcompanion/app/modules/foundations/SwiftTesting/Sources/Expectation.swift",
				},
			},
		])
	})

	test("should parse simple tool use with input_json_delta format", () => {
		const input = `event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_123","name":"simple_tool","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"param\\":\\"value\\"}"}} `

		const result = extractTextFromStream(input)

		expect(result.text).toBe("")
		expect(result.tools).toEqual([
			{
				name: "simple_tool",
				parameters: {
					param: "value",
				},
			},
		])
	})

	test("should handle tool call with empty parameters", () => {
		const input = `event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_123","name":"empty_tool","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{}"}} `

		const result = extractTextFromStream(input)

		expect(result.text).toBe("")
		expect(result.tools).toEqual([
			{
				name: "empty_tool",
				parameters: {},
			},
		])
	})

	test("should handle malformed JSON in new format", () => {
		const input = `event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_123","name":"broken_tool","input":{}}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"incomplete\\":\\"json"}} `

		const result = extractTextFromStream(input)

		expect(result.text).toBe("")
		expect(result.tools).toEqual([
			{
				raw: '{"incomplete":"json',
			},
		])
	})
})
