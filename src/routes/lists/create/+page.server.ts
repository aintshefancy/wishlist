import { getConfig } from "$lib/server/config";
import { getActiveMembership } from "$lib/server/group-membership";
import { error, fail, redirect } from "@sveltejs/kit";
import type { Actions, PageServerLoad } from "./$types";
import { getFormatter } from "$lib/i18n";
import { trimToNull } from "$lib/util";
import { getListPropertiesSchema } from "$lib/validations";
import { create } from "$lib/server/list";
import { client } from "$lib/server/prisma";

export const load = (async ({ locals, url }) => {
    const user = locals.user;
    if (!user) {
        redirect(302, `/login?ref=${url.pathname + url.search}`);
    }

    const activeMembership = await getActiveMembership(user);
    const config = await getConfig(activeMembership.groupId);
    if (config.listMode === "registry") {
        const listCount = await client.list.count({
            where: {
                ownerId: user.id,
                groupId: activeMembership.groupId
            }
        });
        if (listCount === 1) {
            redirect(302, "/wishlists/me");
        }
    }

    return {
        list: {
            name: null,
            icon: null,
            owner: {
                name: user.name,
                username: user.username,
                picture: user.picture || null
            }
        }
    };
}) satisfies PageServerLoad;

export const actions: Actions = {
    persist: async ({ request, locals }) => {
        const $t = await getFormatter();
        if (!locals.user) {
            error(401, $t("errors.unauthenticated"));
        }

        const activeMembership = await getActiveMembership(locals.user);
        const config = await getConfig(activeMembership.groupId);
        if (config.listMode === "registry") {
            const listCount = await client.list.count({
                where: {
                    ownerId: locals.user.id,
                    groupId: activeMembership.groupId
                }
            });
            if (listCount === 1) {
                return fail(400, {
                    success: false,
                    error: $t("errors.in-registry-mode-you-can-only-have-one-list")
                });
            }
        }

        const form = await request.formData();
        const listPropertiesSchema = getListPropertiesSchema();
        const listProperties = listPropertiesSchema.safeParse({
            name: form.get("name"),
            icon: form.get("icon"),
            iconColor: form.get("iconColor")
        });
        if (listProperties.error) {
            return fail(422, {
                success: false,
                formErrors: listProperties.error.format()
            });
        }

        let list;
        try {
            const data = {
                name: trimToNull(listProperties.data.name),
                icon: trimToNull(listProperties.data.icon),
                iconColor: trimToNull(listProperties.data.iconColor)
            };
            list = await create(locals.user.id, activeMembership.groupId, data);
        } catch (e) {
            console.log("Unable to create list", e);
            return fail(500, { success: false, error: $t("errors.unable-to-create-list") });
        }

        return redirect(302, `/lists/${list.id}`);
    }
};
