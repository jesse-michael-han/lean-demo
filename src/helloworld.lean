import tactic
import data.nat.parity
import system.io

section warm_up

variables {α β : Type} (p q : α → Prop) (r : α → β → Prop)

lemma exercise_1 : (∀ x, p x) ∧ (∀ x, q x) → ∀ x, p x ∧ q x :=
begin
  intro H, intro x, refine ⟨_,_⟩,
  cases H with Hp Hq, exact Hp x,
  cases H with Hp Hq, exact Hq x
end

#check exercise_1

#check Prop

#check Type

#print and

-- blast our way to the end

example : (∀ x, p x → q x) → (∀ x, p x) → ∀ x, q x := by finish

example : (∀ x, p x) ∨ (∀ x, q x) → ∀ x, p x ∨ q x := by finish

example : (∃ x, p x ∧ q x) → ∃ x, p x := by finish

example : (∃ x, ∀ y, r x y) → ∀ y, ∃ x, r x y := by tidy

end warm_up

/-
We're going to solve a simplified version of the `coffee can problem`, due to David Gries' `The Science of Programming` (note: really good read).

Suppose you have a coffee can filled with finitely many white and black beans. You have an infinite supply of white and black beans outside the can.

Carry out the following procedure until there is only 1 bean left in the can:

 - Draw two beans
   - if their colors are different (i.e. (white, black) or (black, white)), then you discard the white one and return the black one.
   - if their colors are the same, discard both of them and you add a white bean to the can.

Prove that this process terminates with a single white bean iff the number of black beans is even.

We're going to solve this problem where the coffee can is a list and we only pop and push beans from the head of the list.
-/

/-
  To state this problem , we need:
     - [x] a notion of beans
     - [x] define the "coffee operation"
     - [ ] a way to count the number of white and black beans
     - [ ] a notion of evenness (I'm going to import this from mathlib).
-/

inductive beans : Type
| white : beans
| black : beans

#print beans.cases_on

open beans -- this opens the namespace `beans` so we don't have to qualify the constructors

@[simp]
def coffee : list beans → list beans
| [] := []
| [b] := [b]
| (white::white::bs) := coffee (white::bs)
| (white::black::bs) := coffee (black::bs)
| (black::white::bs) := coffee (black::bs)
| (black::black::bs) := coffee (white::bs)

def some_beans : list beans := [white, black, white, black, black]

instance : has_repr beans :=
{ repr := λ b, beans.cases_on b "◽" "◾" }

#eval coffee (some_beans)


@[simp] -- by tagging this as simp, make all the equation lemmas generated by Lean
-- available to the simplifier
def count_beans : beans → list beans → ℕ
| b [] := 0
| white (white::bs) := count_beans white bs + 1
| white (black::bs) := count_beans white bs
| black (white::bs) := count_beans black bs
| black (black::bs) := count_beans black bs + 1

-- Lean has a powerful built-in simplifier tactic that has access to a global library of
-- `simp lemmas`. `simp` is essentially a confluent rewriting system.

lemma count_beans_is_not_horribly_wrong {xs} : count_beans white xs + count_beans black xs = xs.length :=
begin
  induction xs with hd tl IH,
    { refl },
    { cases hd,
      { simp, rw ← IH, omega }, -- omega will decide linear Presburger arith
      { simp, rw ← IH, omega } }
end

open nat -- open nat namespace to avoid qualifying imported defs

lemma coffee_lemma_1 {x : beans} {xs : list beans} : even (count_beans black (x::xs)) ↔ even (count_beans black $ coffee (x::xs)) :=
begin
  induction xs with hd tl IH generalizing x,
    { cases x; simp },
    { cases x; cases hd,
      all_goals {try {simp * at *}},
     have := @IH white, simp * with parity_simps at *,

    have := @IH black, simp * with parity_simps at *,

    have := @IH black, simp * with parity_simps at *,

    have := @IH white, simp * with parity_simps at * }
end

lemma coffee_lemma_2 {x : beans} {xs : list beans} : coffee (x::xs) = [white] ∨ coffee (x::xs) = [black] :=
begin
  induction xs with hd tl IH generalizing x,
    { cases x, simp, simp },
    { cases x; cases hd,
      all_goals { simp * at * }}
end

theorem coffee_can_problem {x : beans} {xs : list beans} :
  coffee (x::xs) = [white] ↔ even (count_beans black (x::xs)) :=
begin
  have H₁ : even (count_beans black (x::xs)) ↔ even (count_beans black $ coffee (x::xs)),
  by { apply coffee_lemma_1 },
  have H₂ : coffee (x::xs) = [white] ∨ coffee (x::xs) = [black],
  by { apply coffee_lemma_2 },
  cases H₂,
    { refine ⟨_,_⟩,
       { intro H, rw H₁, rw H, simp },
       { intro H, assumption }},
    { 
    refine ⟨_,_⟩,
      { intro H_bad, exfalso, cc }, -- cc is the congruence closure tactic
                                    -- chains together equalities and knows
                                    -- how to reach simple contradictions
                                    -- involving constructors
      { intro H, exfalso, rw H₁ at H, rw H₂ at H, simp at H, exact H }}
end

def coffee2 : list beans → list beans := λ bns,
match bns with
| [] := []
| bns := let num_black_beans := count_beans black bns in
         if (even num_black_beans) then [white] else [black]
end

theorem coffee_coffee2 : coffee = coffee2 :=
begin
  funext bns, cases bns,
    { simp[coffee2] },
    { by_cases H : even (count_beans black $ bns_hd :: bns_tl),
      { simp [coffee2, *], rwa ← coffee_can_problem at H },
      { simp [coffee2, *], rw ← coffee_can_problem at H, finish using coffee_lemma_2 }}
end

namespace tactic
namespace interactive
namespace tactic_parser

section metaprogramming

@[reducible]meta def tactic_parser : Type → Type := state_t string tactic

meta def tactic_parser.run {α} : tactic_parser α → string → tactic α :=
λ p σ, prod.fst <$> state_t.run p σ

meta def parse_char : tactic_parser string :=
{ run := λ s, match s with
              | ⟨[]⟩ := tactic.failed
              | ⟨(c::cs)⟩ := prod.mk <$> return ⟨[c]⟩ <*> return ⟨cs⟩
              end }

meta def failed {α} : tactic_parser α := {run := λ s, tactic.failed}

meta def parse_bean : tactic_parser beans :=
do c ← parse_char,
   if c = "1" then return white else
   if c = "0" then return black else failed

meta def repeat {α} : tactic_parser α → tactic_parser (list α) :=
λ p, (list.cons <$> p <*> repeat p) <|> return []

meta instance format_of_repr {α} [has_repr α] : has_to_tactic_format α :=
{ to_tactic_format := λ b,
    return (let f := (by apply_instance : has_repr α).repr in format.of_string (f b))}

run_cmd ((repeat parse_bean).run "101010111001" >>= tactic.trace)

-- #eval some_more_beans

end metaprogramming
end tactic_parser
end interactive
end tactic

-- run this file with `lean --run hello_world.lean`
def main : io unit :=
do trace (string.join ((by apply_instance : has_repr beans).repr <$> [white, black, white, black, black, black, white])) (return ()),
   trace ("Hello world!") (return ())
