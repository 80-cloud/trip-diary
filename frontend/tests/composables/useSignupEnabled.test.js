import { describe, it, expect, afterEach } from "vitest"
import { useSignupEnabled } from "~/composables/useSignupEnabled.js"

const originalRuntimeConfig = globalThis.useRuntimeConfig

function setSignupEnabled(value) {
  globalThis.useRuntimeConfig = () => ({ public: { signupEnabled: value } })
}

describe("useSignupEnabled", () => {
  afterEach(() => {
    globalThis.useRuntimeConfig = originalRuntimeConfig
  })

  it("returns true when signupEnabled is not set", () => {
    setSignupEnabled(undefined)
    expect(useSignupEnabled()).toBe(true)
  })

  it("returns true when signupEnabled is true", () => {
    setSignupEnabled(true)
    expect(useSignupEnabled()).toBe(true)
  })

  it("returns false when signupEnabled is false", () => {
    setSignupEnabled(false)
    expect(useSignupEnabled()).toBe(false)
  })

  it("returns false when signupEnabled is the string false", () => {
    setSignupEnabled("false")
    expect(useSignupEnabled()).toBe(false)
  })
})
