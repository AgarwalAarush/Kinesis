#!/usr/bin/env python3
"""Webcam hand-tracking helper for Kinesis v0.

The process writes newline-delimited JSON intents to stdout. The Swift app owns
all macOS control; this helper only reports measured gesture intent.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from dataclasses import dataclass
from typing import Iterable, Sequence


Point = tuple[float, float, float]


@dataclass
class HelperConfig:
    smoothing: float = 0.35
    pinch_threshold: float = 0.30
    hold_seconds: float = 0.28
    tap_max_seconds: float = 0.26
    min_confidence: float = 0.55


@dataclass
class HelperState:
    previous_index: Point | None = None
    previous_scroll_center: Point | None = None
    smoothed_cursor: tuple[float, float] = (0.0, 0.0)
    smoothed_scroll: tuple[float, float] = (0.0, 0.0)
    pinch_started_at: float | None = None
    drag_active: bool = False
    frame_count: int = 0
    fps_started_at: float = 0.0


def distance(a: Point, b: Point) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def palm_width(landmarks: Sequence[Point]) -> float:
    return max(distance(landmarks[5], landmarks[17]), 0.001)


def pinch_ratio(landmarks: Sequence[Point]) -> float:
    return distance(landmarks[4], landmarks[8]) / palm_width(landmarks)


def finger_extensions(landmarks: Sequence[Point]) -> dict[str, bool]:
    return {
        "thumb": landmarks[4][0] < landmarks[3][0],
        "index": landmarks[8][1] < landmarks[6][1],
        "middle": landmarks[12][1] < landmarks[10][1],
        "ring": landmarks[16][1] < landmarks[14][1],
        "pinky": landmarks[20][1] < landmarks[18][1],
    }


def low_pass(previous: tuple[float, float], current: tuple[float, float], smoothing: float) -> tuple[float, float]:
    smoothing = min(max(smoothing, 0.0), 0.95)
    return (
        previous[0] * smoothing + current[0] * (1.0 - smoothing),
        previous[1] * smoothing + current[1] * (1.0 - smoothing),
    )


def vector_between(previous: Point | None, current: Point, scale: float) -> tuple[float, float]:
    if previous is None:
        return (0.0, 0.0)
    return ((current[0] - previous[0]) * scale, (current[1] - previous[1]) * scale)


def intent_payload(
    *,
    timestamp: float,
    tracking: str,
    gesture: str,
    confidence: float,
    cursor_delta: tuple[float, float] = (0.0, 0.0),
    scroll_delta: tuple[float, float] = (0.0, 0.0),
    click: str = "none",
    handedness: str = "unknown",
    fps: float = 0.0,
) -> dict:
    return {
        "timestamp": timestamp,
        "tracking": tracking,
        "gesture": gesture,
        "confidence": round(confidence, 4),
        "cursorDelta": {"dx": round(cursor_delta[0], 4), "dy": round(cursor_delta[1], 4)},
        "scrollDelta": {"dx": round(scroll_delta[0], 4), "dy": round(scroll_delta[1], 4)},
        "click": click,
        "diagnostics": {"handedness": handedness, "fps": round(fps, 2)},
    }


def classify_landmarks(
    landmarks: Sequence[Point] | None,
    state: HelperState,
    config: HelperConfig,
    *,
    timestamp: float | None = None,
    handedness: str = "unknown",
    confidence: float = 0.90,
) -> dict:
    now = time.time() if timestamp is None else timestamp
    fps = update_fps(state, now)

    if landmarks is None:
        state.previous_index = None
        state.previous_scroll_center = None
        click = release_if_dragging(state)
        return intent_payload(
            timestamp=now,
            tracking="lost",
            gesture="none",
            confidence=0.0,
            click=click,
            handedness=handedness,
            fps=fps,
        )

    fingers = finger_extensions(landmarks)
    extended = sum(fingers.values())
    index_tip = landmarks[8]
    scroll_center = midpoint(landmarks[8], landmarks[12])
    ratio = pinch_ratio(landmarks)
    pinched = ratio < config.pinch_threshold
    click = "none"

    if extended <= 1 and not fingers["index"]:
        state.previous_index = None
        state.previous_scroll_center = None
        click = release_if_dragging(state)
        return intent_payload(timestamp=now, tracking="paused", gesture="fist_pause", confidence=0.95, click=click, handedness=handedness, fps=fps)

    if extended >= 4:
        state.previous_index = None
        state.previous_scroll_center = None
        click = release_if_dragging(state)
        return intent_payload(timestamp=now, tracking="paused", gesture="open_palm_pause", confidence=0.95, click=click, handedness=handedness, fps=fps)

    gesture = "none"
    cursor_delta = (0.0, 0.0)
    scroll_delta = (0.0, 0.0)

    if pinched:
        if state.pinch_started_at is None:
            state.pinch_started_at = now
        elif not state.drag_active and now - state.pinch_started_at >= config.hold_seconds:
            state.drag_active = True
            click = "down"
        gesture = "pinch_hold" if state.drag_active else "pinch"
    elif state.pinch_started_at is not None:
        duration = now - state.pinch_started_at
        if state.drag_active:
            click = "up"
        elif duration <= config.tap_max_seconds:
            click = "tap"
        state.pinch_started_at = None
        state.drag_active = False

    if fingers["index"] and fingers["middle"] and not fingers["ring"]:
        raw_scroll = vector_between(state.previous_scroll_center, scroll_center, -1200.0)
        state.smoothed_scroll = low_pass(state.smoothed_scroll, raw_scroll, config.smoothing)
        state.previous_scroll_center = scroll_center
        state.previous_index = None
        gesture = "two_finger_scroll"
        scroll_delta = state.smoothed_scroll
    elif fingers["index"]:
        raw_cursor = vector_between(state.previous_index, index_tip, 100.0)
        state.smoothed_cursor = low_pass(state.smoothed_cursor, raw_cursor, config.smoothing)
        state.previous_index = index_tip
        state.previous_scroll_center = None
        if gesture == "none":
            gesture = "index_move"
        cursor_delta = state.smoothed_cursor
    else:
        state.previous_index = None
        state.previous_scroll_center = None

    return intent_payload(
        timestamp=now,
        tracking="active",
        gesture=gesture,
        confidence=confidence,
        cursor_delta=cursor_delta,
        scroll_delta=scroll_delta,
        click=click,
        handedness=handedness,
        fps=fps,
    )


def midpoint(a: Point, b: Point) -> Point:
    return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, (a[2] + b[2]) / 2.0)


def release_if_dragging(state: HelperState) -> str:
    if state.drag_active:
        state.drag_active = False
        state.pinch_started_at = None
        return "up"
    state.pinch_started_at = None
    return "none"


def update_fps(state: HelperState, now: float) -> float:
    if state.fps_started_at <= 0:
        state.fps_started_at = now
    state.frame_count += 1
    elapsed = max(now - state.fps_started_at, 0.001)
    return state.frame_count / elapsed


def landmarks_from_mediapipe(hand_landmarks) -> list[Point]:
    return [(lm.x, lm.y, lm.z) for lm in hand_landmarks.landmark]


def run_camera(config: HelperConfig) -> int:
    try:
        import cv2
        import mediapipe as mp
    except ImportError as exc:
        print(f"Missing CV dependency: {exc}. Run script/setup_cv_env.sh first.", file=sys.stderr, flush=True)
        return 2

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Could not open webcam 0.", file=sys.stderr, flush=True)
        return 3

    state = HelperState()
    hands = mp.solutions.hands.Hands(
        static_image_mode=False,
        max_num_hands=1,
        min_detection_confidence=0.6,
        min_tracking_confidence=0.6,
    )

    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                print(json.dumps(classify_landmarks(None, state, config)), flush=True)
                time.sleep(0.05)
                continue

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result = hands.process(rgb)

            if not result.multi_hand_landmarks:
                payload = classify_landmarks(None, state, config)
            else:
                handedness = "unknown"
                score = 0.90
                if result.multi_handedness:
                    classification = result.multi_handedness[0].classification[0]
                    handedness = classification.label.lower()
                    score = float(classification.score)
                payload = classify_landmarks(
                    landmarks_from_mediapipe(result.multi_hand_landmarks[0]),
                    state,
                    config,
                    handedness=handedness,
                    confidence=max(score, config.min_confidence),
                )

            print(json.dumps(payload), flush=True)
    except KeyboardInterrupt:
        return 0
    finally:
        hands.close()
        cap.release()


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Kinesis webcam gesture helper")
    parser.add_argument("--smoothing", type=float, default=0.35)
    parser.add_argument("--pinch-threshold", type=float, default=0.30)
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    config = HelperConfig(smoothing=args.smoothing, pinch_threshold=args.pinch_threshold)
    return run_camera(config)


if __name__ == "__main__":
    raise SystemExit(main())
