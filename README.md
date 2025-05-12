# TrackingAPI.jl
[![CI](https://github.com/pebeto/TrackingAPI.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/pebeto/TrackingAPI.jl/actions/workflows/CI.yml)
A full-featured solution for machine learning lifecycle (made in Julia) with a focus on tracking and reproducibility.

> [!IMPORTANT]
> This package is in an early development stage and is not yet ready for production use. The API may change significantly in the future.

### Motivation
After working with several machine learning lifecycle tools over the years, I found that most of them are bloated with features that just the 0.1% of users will ever use. I always loved the Unix philosophy of "do one thing and do it well"; that's the core motivation.
Simple well defined projects mean smart design, easy to use, and easy to maintain. Well-architected projects are easy to extend and adapt to your needs. This is the goal of this package.

## Features
- A complete solution for machine learning projects
- Built-in REST API for integration with other tools
- Support for asynchronous and distributed training
- Portability thanks to SQLite
- Built in Julia

## FAQ
### What's different from MLFlow?
MLFlow is a great tool, and I recommend it. However, I found it to be bloated with features that I don't need. This is the same opinion I have about most of the tools in this space.

### Why Julia?
I love  Julia; that's the main reason. This programming language, far from being fast, is highly interpretable and easy to use. You don't need to be a computer scientist to understand it, do you know that machine learning is also used by biologists, chemists, physicists, economists, and so on?

### Julia is not popular, why you are using it?
To make it popular.

### Why SQLite?
Why not? SQLite is a great solution for storing data. It's fast, reliable, portable, and easy to use. Most of the time, you don't need a full-fledged database server, or an over-complicated cloud solution. Stop overengineering your projects, that's stupid.

### Any UI in mind?
Not yet. I want to focus on the API first. However, I have an idea in mind inspired by [Pluto.jl](https://github.com/fonsp/Pluto.jl).

### How to contribute?
Open an issue or a pull request. I will be happy to review it in my free time.
