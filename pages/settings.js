for (const anchor of document.querySelectorAll(".option-anchor")) {
    const id = anchor.id
    const option = anchor.closest(".option");
    option.removeChild(anchor);
    option.id = id;
}

const get_option_from_hash = hash => {
    const id = decodeURIComponent(hash.slice(1));
    return id == "" ? null : document.getElementById(id);
};

const expand = option => {
    if (option != null) {
        option.open = true;
        expand(option.parentElement?.closest(".option"));
    }
}

const jump_to = option => {

    expand(option);
    option.scrollIntoView();
    const expected_hash = `#${encodeURIComponent(option.id)}`;
    if (window.location.hash != expected_hash) {
        history.pushState({}, "", expected_hash);
    }
};

window.addEventListener("DOMContentLoaded", event => {
    const option = get_option_from_hash(event.target.location.hash);
    if (option) { jump_to(option) }
});

window.addEventListener("hashchange", event => {
    const option = get_option_from_hash(event.target.location.hash);
    if (option) { jump_to(option) } else { event.target.location.hash = ""; }
});

window.addEventListener("click", event => {
    const anchor = event.target.closest('a[href^="#"]');
    if (!anchor) return;
    const option = get_option_from_hash(anchor.hash);
    if (!option) return;
    event.preventDefault();
    jump_to(option);
});

const should_focus_on_any_click = window.matchMedia("screen and (hover: none)");

window.addEventListener("click", event => {
    const summary = event.target.closest('.option>summary');
    if (!(summary && should_focus_on_any_click.matches)) return;
    const option = summary.closest(".option");
    if (option.open) return;
    event.preventDefault();
    jump_to(option)
});