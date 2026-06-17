/* Keyleds -- Gaming keyboard tool
 * Copyright (C) 2017 Julien Hartmann, juli1.hartmann@gmail.com
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include "lua/LuaEffect.h"

#include "keyledsd/KeyDatabase.h"
#include "keyledsd/RenderTarget.h"
#include "keyledsd/colors.h"
#include "keyledsd/logging.h"
#include "keyledsd/plugin/interfaces.h"
#include <gtest/gtest.h>
#include <algorithm>
#include <chrono>
#include <string>
#include <vector>

using keyleds::KeyDatabase;
using keyleds::RenderTarget;
using keyleds::plugin::EffectService;
using keyleds::plugin::lua::LuaEffect;

namespace {

/// Minimal EffectService stub. log() captures script output (print) for observation.
class MockEffectService final : public EffectService
{
public:
    const std::string &     deviceName() const override { return m_empty; }
    const std::string &     deviceModel() const override { return m_empty; }
    const std::string &     deviceSerial() const override { return m_empty; }
    const KeyDatabase &     keyDB() const override { return m_keyDB; }
    const std::vector<KeyDatabase::KeyGroup> & keyGroups() const override { return m_keyGroups; }
    const color_map &       colors() const override { return m_colors; }
    const config_map &      configuration() const override { return m_config; }
    RenderTarget *          createRenderTarget() override { return new RenderTarget(0); }
    void                    destroyRenderTarget(RenderTarget * t) override { delete t; }
    const std::string &     getFile(const std::string &) override { return m_empty; }
    void                    log(keyleds::logging::level_t, const char * msg) override
                                { logs.emplace_back(msg); }

    std::vector<std::string> logs;     ///< Captured print()/log output
private:
    std::string             m_empty;
    KeyDatabase             m_keyDB;
    std::vector<KeyDatabase::KeyGroup> m_keyGroups;
    color_map               m_colors;
    config_map              m_config;
};

// Effect with a thread that bumps `ticks` once per wake, printing it each frame.
// `elapsed` (40ms) < wait (50ms) => exactly one wake per frame.
// Regression guard for the delta-time bug: when render() steps by
// (elapsed - lastElapsed) it collapses to 0 from frame 2 on, the thread
// never wakes again and ticks stays 0. Stepping by `elapsed` advances it.
// Same `elapsed` is fed to stepInterpolators(), so this also pins that path.
constexpr char counterEffect[] = R"lua(
ticks = 0
function counter()
    while true do
        wait(0.050)
        ticks = ticks + 1
    end
end
thread(counter)
function render(ms, target)
    print(tostring(ticks))
end
)lua";

} // namespace

TEST(LuaEffectTest, threadsAdvanceEachFrame)
{
    MockEffectService service;
    auto effect = LuaEffect::create("counter", service, counterEffect);
    ASSERT_NE(effect, nullptr);

    RenderTarget target(0);
    constexpr int frames = 6;
    for (int frame = 0; frame < frames; ++frame) {
        effect->render(std::chrono::milliseconds(40), target);
    }

    int maxTicks = 0;
    for (const auto & entry : service.logs) {
        try { maxTicks = std::max(maxTicks, std::stoi(entry)); } catch (...) { /* non-numeric */ }
    }
    // The delta-time bug freezes the thread, so maxTicks stays 0. The fix advances it
    // ~once per frame; assert with headroom (not the exact count) so minor timing/schedule
    // tweaks never turn this into a brittle false failure.
    EXPECT_GT(maxTicks, 0);
    EXPECT_GE(maxTicks, frames / 2);
}
