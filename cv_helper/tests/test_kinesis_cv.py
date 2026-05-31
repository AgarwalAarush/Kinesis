from cv_helper.kinesis_cv import HelperConfig, HelperState, classify_landmarks, low_pass, pinch_ratio


def hand_pose(*, index=True, middle=False, ring=False, pinky=False, pinched=False):
    points = [(0.5, 0.8, 0.0) for _ in range(21)]
    points[0] = (0.5, 0.9, 0.0)
    points[5] = (0.45, 0.65, 0.0)
    points[17] = (0.65, 0.65, 0.0)
    points[3] = (0.42, 0.68, 0.0)
    points[4] = (0.38, 0.58, 0.0)

    set_finger(points, 8, 6, index)
    set_finger(points, 12, 10, middle)
    set_finger(points, 16, 14, ring)
    set_finger(points, 20, 18, pinky)

    if pinched:
        points[4] = (points[8][0] + 0.01, points[8][1] + 0.01, 0.0)

    return points


def set_finger(points, tip, pip, extended):
    x = 0.4 + tip / 100
    points[pip] = (x, 0.62, 0.0)
    points[tip] = (x, 0.42 if extended else 0.72, 0.0)


def test_low_pass_smooths_toward_current_delta():
    assert low_pass((0, 0), (10, -10), 0.5) == (5, -5)


def test_pinch_ratio_drops_for_pinched_pose():
    open_hand = hand_pose(index=True)
    pinched = hand_pose(index=True, pinched=True)
    assert pinch_ratio(pinched) < pinch_ratio(open_hand)


def test_index_finger_motion_emits_cursor_delta():
    state = HelperState()
    config = HelperConfig(smoothing=0.0)
    first = hand_pose(index=True)
    second = hand_pose(index=True)
    second[8] = (first[8][0] + 0.05, first[8][1] + 0.02, 0)

    classify_landmarks(first, state, config, timestamp=1.0)
    payload = classify_landmarks(second, state, config, timestamp=1.1)

    assert payload["tracking"] == "active"
    assert payload["gesture"] == "index_move"
    assert payload["cursorDelta"]["dx"] > 0


def test_quick_pinch_release_emits_tap():
    state = HelperState()
    config = HelperConfig()
    classify_landmarks(hand_pose(index=True, pinched=True), state, config, timestamp=1.0)
    payload = classify_landmarks(hand_pose(index=True, pinched=False), state, config, timestamp=1.1)
    assert payload["click"] == "tap"


def test_pinch_hold_emits_drag_down_then_release_up():
    state = HelperState()
    config = HelperConfig(hold_seconds=0.2)
    classify_landmarks(hand_pose(index=True, pinched=True), state, config, timestamp=1.0)
    down = classify_landmarks(hand_pose(index=True, pinched=True), state, config, timestamp=1.25)
    up = classify_landmarks(hand_pose(index=True, pinched=False), state, config, timestamp=1.4)
    assert down["click"] == "down"
    assert up["click"] == "up"


def test_two_finger_motion_emits_scroll_delta():
    state = HelperState()
    config = HelperConfig(smoothing=0.0)
    first = hand_pose(index=True, middle=True)
    second = hand_pose(index=True, middle=True)
    second[8] = (first[8][0], first[8][1] - 0.04, 0)
    second[12] = (first[12][0], first[12][1] - 0.04, 0)

    classify_landmarks(first, state, config, timestamp=1.0)
    payload = classify_landmarks(second, state, config, timestamp=1.1)

    assert payload["gesture"] == "two_finger_scroll"
    assert payload["scrollDelta"]["dy"] > 0


def test_pause_gestures_are_reported():
    state = HelperState()
    config = HelperConfig()
    fist = hand_pose(index=False, middle=False, ring=False, pinky=False)
    palm = hand_pose(index=True, middle=True, ring=True, pinky=True)
    assert classify_landmarks(fist, state, config, timestamp=1.0)["gesture"] == "fist_pause"
    assert classify_landmarks(palm, state, config, timestamp=1.1)["gesture"] == "open_palm_pause"


def test_lost_hand_releases_active_drag():
    state = HelperState()
    config = HelperConfig(hold_seconds=0.2)
    classify_landmarks(hand_pose(index=True, pinched=True), state, config, timestamp=1.0)
    classify_landmarks(hand_pose(index=True, pinched=True), state, config, timestamp=1.3)
    payload = classify_landmarks(None, state, config, timestamp=1.4)
    assert payload["tracking"] == "lost"
    assert payload["click"] == "up"
