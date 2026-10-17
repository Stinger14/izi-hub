import asyncio

from app.modules.studio.schemas import (
    CaptionRequest,
    CaptionResult,
    CaptionVariant,
    RepurposeRequest,
    RepurposeResult,
)
from app.services.claude_writer import ClaudeWriter
from app.services.studio_writer import StudioWriter, normalize_hashtags
from tests.fakes import FakeAnthropic


def writer_with(result):
    client = FakeAnthropic(parsed_output=result)
    return StudioWriter(ClaudeWriter(client, "claude-opus-5-5", "medium")), client


def test_caption_puts_source_in_tags_and_cleans_hashtags():
    result = CaptionResult(
        variants=[CaptionVariant(caption="Hola", cta="Comenta")],
        hashtags=["#RD", "rd", " santo domingo ", "", "#Comida"],
    )
    writer, client = writer_with(result)

    out = asyncio.run(writer.caption(CaptionRequest(source="mi receta de mangú")))

    assert out.hashtags == ["RD", "santodomingo", "Comida"]
    prompt = client.calls[0]["messages"][0]["content"]
    assert "<notes>\nmi receta de mangú\n</notes>" in prompt
    assert "Dominican" in prompt


def test_repurpose_uses_subtitles_when_given():
    result = RepurposeResult(title="t", summary="s", chapters=[], clips=[])
    writer, client = writer_with(result)

    asyncio.run(
        writer.repurpose(
            RepurposeRequest(
                transcript="hola",
                srt="1\n00:00:01,000 --> 00:00:02,000\nhola",
                language="en",
            )
        )
    )

    prompt = client.calls[0]["messages"][0]["content"]
    assert "<subtitles>" in prompt
    assert "conversational English" in prompt


def test_repurpose_without_subtitles_asks_for_estimates():
    result = RepurposeResult(title="t", summary="s", chapters=[], clips=[])
    writer, client = writer_with(result)

    asyncio.run(writer.repurpose(RepurposeRequest(transcript="hola")))

    prompt = client.calls[0]["messages"][0]["content"]
    assert "<subtitles>" not in prompt
    assert "estimate" in prompt


def test_normalize_hashtags_keeps_first_spelling():
    assert normalize_hashtags(["#Polo", "polo", "#POLO", "Studio"]) == [
        "Polo",
        "Studio",
    ]
