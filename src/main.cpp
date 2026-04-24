#include "Engine/Window.hpp"
#include "Engine/EventBus.hpp"
#include "Engine/Renderer.hpp"
#include "UI/Components.hpp"
#include <iostream>
#include <memory>

int main(int argc, char* args[]) {
    Window window("Professional Creative Suite - New Project", 1280, 720);

    if (!window.Initialize()) {
        return 1;
    }

    Renderer renderer(window.GetSDLWindow());
    if (!renderer.Initialize()) {
        return 1;
    }

    // --- Build UI Tree ---
    auto root = std::make_shared<Panel>(C_BACKGROUND, false);
    root->SetRect({0, 0, 1280, 720});

    // Modal Background Dim (Optional, just use a darker background for now)

    // Modal Container
    int modalWidth = 600;
    int modalHeight = 440;
    int mx = (1280 - modalWidth) / 2;
    int my = (720 - modalHeight) / 2;

    auto modal = std::make_shared<Panel>(C_SURFACE_CONTAINER_HIGHEST, true);
    modal->SetRect({mx, my, modalWidth, modalHeight});
    root->AddChild(modal);

    // Header
    auto title = std::make_shared<Label>("New Project", "Inter Semi-Bold 18", C_ON_SURFACE);
    title->SetRect({mx + S_LG, my + S_LG, 400, 24});
    modal->AddChild(title);

    auto subtitle = std::make_shared<Label>("Configure your karaoke project settings.", "Inter 13", C_ON_SURFACE_VARIANT);
    subtitle->SetRect({mx + S_LG, my + S_LG + 24 + S_SM, 400, 18});
    modal->AddChild(subtitle);

    // Close 'X'
    auto closeBtn = std::make_shared<Label>("X", "Inter Semi-Bold 14", C_ON_SURFACE_VARIANT);
    closeBtn->SetRect({mx + modalWidth - S_LG - 10, my + S_LG, 20, 20});
    modal->AddChild(closeBtn);

    // Divider line (using a slim panel)
    auto divider1 = std::make_shared<Panel>(C_OUTLINE_VARIANT, false);
    divider1->SetRect({mx, my + 80, modalWidth, 1});
    modal->AddChild(divider1);

    int formY = my + 80 + S_LG;

    // Project Name
    auto lblProjName = std::make_shared<Label>("PROJECT NAME", "Inter Bold 11", C_ON_SURFACE);
    lblProjName->SetRect({mx + S_LG, formY, 400, 16});
    modal->AddChild(lblProjName);

    auto inputProjName = std::make_shared<TextInput>("Untitled Project");
    inputProjName->SetRect({mx + S_LG, formY + 16 + S_SM, modalWidth - S_LG*2, 32});
    modal->AddChild(inputProjName);

    formY += 16 + S_SM + 32 + S_LG;

    // Artist
    auto lblArtist = std::make_shared<Label>("ARTIST", "Inter Bold 11", C_ON_SURFACE);
    lblArtist->SetRect({mx + S_LG, formY, 400, 16});
    modal->AddChild(lblArtist);

    auto inputArtist = std::make_shared<TextInput>("e.g. Frank Sinatra");
    inputArtist->SetRect({mx + S_LG, formY + 16 + S_SM, modalWidth - S_LG*2, 32});
    modal->AddChild(inputArtist);

    formY += 16 + S_SM + 32 + S_LG;

    // Audio File
    auto lblAudio = std::make_shared<Label>("AUDIO FILE", "Inter Bold 11", C_ON_SURFACE);
    lblAudio->SetRect({mx + S_LG, formY, 400, 16});
    modal->AddChild(lblAudio);

    auto fileInput = std::make_shared<FileInput>();
    fileInput->SetRect({mx + S_LG, formY + 16 + S_SM, modalWidth - S_LG*2, 32});
    modal->AddChild(fileInput);

    formY += 16 + S_SM + 32 + S_LG;

    // Split Row: Aspect Ratio & Resolution
    auto lblAspect = std::make_shared<Label>("ASPECT RATIO", "Inter Bold 11", C_ON_SURFACE);
    lblAspect->SetRect({mx + S_LG, formY, 200, 16});
    modal->AddChild(lblAspect);

    auto dropAspect = std::make_shared<Dropdown>("16:9 Widescreen");
    dropAspect->SetRect({mx + S_LG, formY + 16 + S_SM, (modalWidth - S_LG*2)/2 - S_SM, 32});
    modal->AddChild(dropAspect);

    auto lblRes = std::make_shared<Label>("RESOLUTION", "Inter Bold 11", C_ON_SURFACE);
    lblRes->SetRect({mx + S_LG + (modalWidth - S_LG*2)/2 + S_SM, formY, 200, 16});
    modal->AddChild(lblRes);

    auto dropRes = std::make_shared<Dropdown>("1080p (1920x1080)");
    dropRes->SetRect({mx + S_LG + (modalWidth - S_LG*2)/2 + S_SM, formY + 16 + S_SM, (modalWidth - S_LG*2)/2 - S_SM, 32});
    modal->AddChild(dropRes);

    // Footer divider
    auto divider2 = std::make_shared<Panel>(C_OUTLINE_VARIANT, false);
    divider2->SetRect({mx, my + modalHeight - 64, modalWidth, 1});
    modal->AddChild(divider2);

    // Buttons
    auto cancelBtn = std::make_shared<Button>("Cancel", false);
    cancelBtn->SetRect({mx + modalWidth - S_LG - 120 - S_MD - 80, my + modalHeight - 64 + S_MD, 80, 32});
    modal->AddChild(cancelBtn);

    auto createBtn = std::make_shared<Button>("Create Project", true);
    createBtn->SetRect({mx + modalWidth - S_LG - 120, my + modalHeight - 64 + S_MD, 120, 32});
    modal->AddChild(createBtn);

    // Event routing
    EventBus::GetInstance().Subscribe(EventType::MouseClick, [root](const Event& e) {
        // recursively route... (simplified for this prototype, we'd normally traverse)
        // just let UIElement handle via virtual OnEvent
        // root->OnEvent(e);
    });

    bool isRunning = true;
    while (isRunning) {
        window.PollEvents(isRunning);

        renderer.BeginFrame();

        root->Draw(&renderer);

        renderer.EndFrame();

        SDL_Delay(16);
    }

    return 0;
}
