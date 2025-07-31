// copied from https://github.com/RooVetGit/Roo-Code/blob/4f727142ae6f85d04949ac9022c1e38d71c8c63d

import * as path from "path"

import { CheckpointServiceOptions } from "./types"
import { ShadowCheckpointService } from "./ShadowCheckpointService"

export class RepoPerTaskCheckpointService extends ShadowCheckpointService {
	public static create({ taskId, workspaceDir, shadowDir, log = console.log }: CheckpointServiceOptions) {
		return new RepoPerTaskCheckpointService(
			taskId,
			path.join(shadowDir, "tasks", taskId.replace(/[/\\]/g, "_"), "checkpoints"),
			workspaceDir,
			log,
		)
	}
}
