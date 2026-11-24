---
title: Just Be Brave
date: 2026-11-22
slug: just-be-brave
readingTime: 3
summary: "In the age of agent-driven development, we should feel empowered to be brave."
---

A couple of weeks ago at a routine standup, a teammate described a blocker: our 
AWS Lambda zip artifact had outgrown the size limit. I recalled that the fix already 
existed — a sister team had been working on containerizing our Lambdas, which have 
a far higher limit. The migration had been abandoned halfway, because the previous 
engineer was afraid the migration would break our software. I jokingly lamented to
my teammate "Why couldn't the previous engineer just be brave?" We already had a suite 
of unit, integration, and canary tests. If their change was going to break something, 
our testing mechanisms would catch it.

That situation was not unusual. I hear the same hesitation in different forms all the 
time — ideas brushed off because of a fear of breaking something, even when the 
safeguards to prevent exactly that are already in place. Yet, I understand where 
it comes from, especially now. In the age of AI-assisted development, we review and 
merge more code every day that we did not write, design, or test ourselves. Moreover, 
roughly every three months a new paradigm arrives that produces more software with 
even less human verification.

How can we maintain the courage to ship software in these times?

The point, though, is not to trust agents to produce bug-free software. Before agents, 
a feature that passed the testing bar was trusted on an implicit assumption: the 
author understood what they had written. Agents took away the author from the equation. 
Now, more than ever, we must rely on our testing bar to enforce software quality.
If we are uncomfortable trusting features that pass our tests, the problem is not the 
agents. The problem is how our software is written. 
Weak tests were always dangerous. They were just hidden behind an author's reputation.
Agent-produced software that passes your organization's testing bar should be trusted
in your production environment.

This observation generalizes beyond software. In whatever part of life a decision feels 
scary, the question is rarely whether the outcome is certain (it almost never is!) but
instead whether the right guardrails are in place. If you have done your due diligence 
and are reasonably prepared for the outcomes, or, the downsides are small enough
relative to the upsides, uncertainty about the result is not 
a reason to pass up an opportunity. As a matter of fact, you should feel empowered to
be brave. It is my goal to apply this principle in more parts of my life in and outside 
of my career - this blog included. (Historically, I have not been a good or consistent 
writer) In any case, I felt the tagline would make a fine blog title.

Just be brave.
