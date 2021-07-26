import debug from "debug";
import express from "express";
import { getBoards } from "../boards/queries";
import { processBoardsSummary } from "../../utils/response-utils";
import {
  ensureLoggedIn,
  isLoggedIn,
  withUserSettings,
} from "../../handlers/auth";
import { getSettingsBySlug } from "./queries";
import { processRealmActivity } from "./utils";

const info = debug("bobaserver:users:routes-info");
const log = debug("bobaserver:users:routes-log");
const error = debug("bobaserver:users:routes-error");

const router = express.Router();

/**
 * @openapi
 * realms/slug/{realm_slug}/:
 *   get:
 *     summary: Fetches the top-level realm metadata by slug.
 *     tags:
 *       - /realms/
 *     parameters:
 *       - name: realm_slug
 *         in: path
 *         description: The slug of the realm.
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: The realm metadata.
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/Realm"
 */
router.get(
  "/slug/:realm_slug",
  isLoggedIn,
  withUserSettings,
  async (req, res) => {
    try {
      const currentUserSettings = req.currentUser?.settings || [];
      const { realm_slug } = req.params;
      const settings = await getSettingsBySlug({
        realmSlug: realm_slug,
        userSettings: currentUserSettings,
      });

      // TODO[realms]: use a per-realm query here
      const boards = await getBoards({
        firebaseId: req.currentUser?.uid,
      });

      if (!boards) {
        res.status(500);
      }

      const realmBoards = processBoardsSummary({
        boards,
        isLoggedIn: !!req.currentUser?.uid,
      });
      res.status(200).json({
        slug: realm_slug,
        settings,
        boards: realmBoards,
      });
    } catch (e) {
      error(e);
      res.status(500).json({
        message: "There was an error fetching realm data.",
      });
    }
  }
);

/**
 * @openapi
 * realms/{realm_id}/activity:
 *   get:
 *     summary: Fetches latest activity summary for the realm.
 *     tags:
 *       - /realms/
 *     security:
 *       - []
 *       - firebase: []
 *     parameters:
 *       - name: realm_id
 *         in: path
 *         description: The id of the realm.
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: The realm activity summary.
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/RealmActivity"
 */
router.get("/:realm_id/activity", isLoggedIn, async (req, res) => {
  try {
    const { realm_id } = req.params;

    // TODO[realms]: use a per-realm query here
    const boards = await getBoards({
      firebaseId: req.currentUser?.uid,
    });

    if (!boards) {
      res.status(500);
    }

    const realmBoards = processRealmActivity({
      boards,
    });
    res.status(200).json({
      boards: realmBoards,
    });
  } catch (e) {
    error(e);
    res.status(500).json({
      message: "There was an error fetching realm data.",
    });
  }
});

export default router;