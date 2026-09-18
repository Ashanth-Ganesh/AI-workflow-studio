# Visual Multimodal AI Workflow Platform

## Ashanth Ganesh, Daniel Kreifels, Kheim Ha, Jayrajsinh Gohil 

## Economic
The project must account for the costs associated with integrating cloud AI services such as Azure AI, AWS AI, Google Vertex AI, and OpenAI APIs.
Because the platform is intended to remain cloud-provider agnostic, supporting multiple providers and local models provides alternatives when the cost of a particular service is too high.
This creates a trade-off between economic constraints and functionality, because supporting several cloud providers increases development complexity while giving users more options for managing AI service costs.

## Professional
The project requires specialized knowledge of Angular, backend development with FastAPI or ASP.NET Core, PostgreSQL, Docker, and OAuth/JWT authentication.
The plugin SDK and cloud-provider abstraction layer also require developers to design reusable interfaces that can support different AI services.

## Security
Security is an important constraint because workflows can connect to external REST APIs, databases, email, and storage.
The proposed use of OAuth/JWT authentication provides a mechanism for controlling access to the platform and its workflows.
Adding authentication and other security controls may increase the complexity of the visual workflow system, creating a trade-off between security and the project's goal of providing an accessible, easy-to-use interface.

## Social
The project is intended to make AI application development more accessible by allowing users to construct workflows through a visual node-based interface rather than writing code.
The platform supports workflows involving text, documents, images, audio, and video, allowing the same visual approach to be applied to multiple types of AI applications.
Its planned reusable nodes and workflow templates can further reduce the amount of specialized programming required to create AI workflows.