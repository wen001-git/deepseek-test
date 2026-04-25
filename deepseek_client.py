import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

client = OpenAI(
    api_key=os.getenv("DEEPSEEK_API_KEY"),
    base_url=os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com"),
)

MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-v4-flash")


def generate_text(system_prompt: str, user_prompt: str) -> str:
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    )
    return response.choices[0].message.content


def generate_stream(system_prompt: str, user_prompt: str, model: str = None, json_mode: bool = False):
    kwargs = dict(
        model=model or MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        stream=True,
    )
    if json_mode:
        kwargs['response_format'] = {'type': 'json_object'}
    stream = client.chat.completions.create(**kwargs)
    for chunk in stream:
        delta_content = chunk.choices[0].delta.content
        if delta_content:
            yield delta_content
        else:
            # No content yet (thinking phase, pause, or stop chunk) — keepalive
            yield ' '
