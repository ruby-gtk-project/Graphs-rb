# frozen_string_literal: true

require "spec_helper"

# Ported from upstream's tests/test_math_evaluation.vala — one example per
# `Test.add_func` upstream registers, in the same order.
RSpec.describe "math-parser/eval" do
  def evaluate(expression)
    Graphs.evaluate_string(expression)
  end

  it "basic-arithmetic" do
    expect(evaluate("1+2")).to eq(3)
    expect(evaluate("10-3")).to eq(7)
    expect(evaluate("4*5")).to eq(20)
    expect(evaluate("20/4")).to eq(5)
  end

  it "operator-precedence" do
    expect(evaluate("2+3*4")).to eq(14)
    expect(evaluate("(2+3)*4")).to eq(20)
    expect(evaluate("2*3+4")).to eq(10)
  end

  it "power-associativity" do
    expect(evaluate("2^3^2")).to eq(512)
    expect(evaluate("(2^3)^2")).to eq(64)
  end

  it "unary-operators" do
    expect(evaluate("-5")).to eq(-5)
    expect(evaluate("+5")).to eq(5)
    expect(evaluate("(-2)^2")).to eq(4)
  end

  it "factorial" do
    expect(evaluate("0!")).to eq(1)
    expect(evaluate("1!")).to eq(1)
    expect(evaluate("5!")).to eq(120)
    expect(evaluate("3!+2")).to eq(8)
  end

  it "implicit-multiplication" do
    expect(evaluate("2(3+4)")).to eq(14)
    expect(evaluate("2pi")).to be_within(1e-10).of(2 * Math::PI)
    expect(evaluate("3sin(0)")).to eq(0)
    expect(evaluate("(1+2)(3+4)")).to eq(21)
  end

  it "constants" do
    expect(evaluate("pi")).to be_within(1e-10).of(Math::PI)
    expect(evaluate("e")).to be_within(1e-10).of(Math::E)
  end

  it "trig-radians" do
    expect(evaluate("sin(0)")).to eq(0)
    expect(evaluate("cos(0)")).to eq(1)
    expect(evaluate("tan(0)")).to eq(0)
    expect(evaluate("sin(pi/2)")).to be_within(1e-10).of(1)
  end

  it "trig-degrees" do
    expect(evaluate("sind(90)")).to be_within(1e-10).of(1)
    expect(evaluate("cosd(180)")).to be_within(1e-10).of(-1)
    expect(evaluate("tand(45)")).to be_within(1e-10).of(1)
  end

  it "inverse-trig" do
    expect(evaluate("asin(1)")).to be_within(1e-10).of(Math::PI / 2)
    expect(evaluate("acos(1)")).to eq(0)
    expect(evaluate("atand(1)")).to be_within(1e-10).of(45)
  end

  it "misc-functions" do
    expect(evaluate("sqrt(16)")).to eq(4)
    expect(evaluate("abs(-5)")).to eq(5)
    expect(evaluate("log(exp(1))")).to be_within(1e-10).of(1)
    expect(evaluate("log10(1000)")).to be_within(1e-10).of(3)
    expect(evaluate("log2(8)")).to be_within(1e-10).of(3)
  end

  it "nested-expressions" do
    expect(evaluate("sqrt((2+3)*4)+sin(pi/2)")).to be_within(1e-10).of(Math.sqrt(20) + 1)
  end

  it "decimal-separator" do
    expect(Graphs.evaluate_string("1,5+2,5", ",")).to eq(4)
  end

  it "division-by-zero" do
    expect { evaluate("1/0") }.to raise_error(Graphs::MathError) { |e| expect(e.kind).to eq(:invalid) }
  end

  it "invalid-factorial-negative" do
    expect { evaluate("(-1)!") }.to raise_error(Graphs::MathError) { |e| expect(e.kind).to eq(:invalid) }
  end

  it "invalid-factorial-fractional" do
    expect { evaluate("3.5!") }.to raise_error(Graphs::MathError) { |e| expect(e.kind).to eq(:invalid) }
  end

  it "operator-associativity" do
    expect(evaluate("10-3-2")).to eq(5)
    expect(evaluate("20/4/2")).to eq(2.5)
    expect(evaluate("2^3^2")).to eq(512)
    expect(evaluate("10-(3-2)")).to eq(9)
    expect(evaluate("20/(4/2)")).to eq(10)
    expect(evaluate("(2^3)^2")).to eq(64)
    expect(evaluate("3!^2")).to eq(36)
    expect(evaluate("2^3!")).to eq(64)
    expect(evaluate("3!!")).to eq(720)
    expect(evaluate("5!-4!-3!")).to eq(90)
    expect(evaluate("-2^2")).to eq(-4)
    expect(evaluate("(-2)^2")).to eq(4)
    expect(evaluate("-2^3!")).to eq(-64)
    expect(evaluate("2*3!")).to eq(12)
    expect(evaluate("2(3!)^2")).to eq(72)
  end

  it "syntax-errors" do
    ["", "1+", "(1+2", "sin()", "*2", "2^^3"].each do |expression|
      expect { evaluate(expression) }.to(
        raise_error(Graphs::MathError) { |e| expect(e.kind).to eq(:syntax) },
      )
    end
  end
end
