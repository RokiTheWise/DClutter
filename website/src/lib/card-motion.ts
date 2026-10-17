import type { Variants } from "motion/react";

export const EASE = [0.22, 1, 0.36, 1] as const;

/**
 * A card's exit direction is only known once the decision is made, so it has
 * to come from `custom` at exit time. That means the exit must be a *function
 * variant* — an inline `exit={...}` object is resolved too early to carry it.
 */
export const cardMotion: Variants = {
  enter: { opacity: 0, scale: 0.94, y: 26 },
  center: {
    opacity: 1,
    scale: 1,
    x: 0,
    y: 0,
    rotate: 0,
    transition: { duration: 0.45, ease: EASE },
  },
  exit: (v: { x: number; y: number }) => ({
    opacity: 0,
    x: v.x,
    y: v.y,
    rotate: v.x / 36,
    transition: { duration: 0.45, ease: EASE },
  }),
};

export const cardMotionReduced: Variants = {
  enter: { opacity: 0 },
  center: { opacity: 1, x: 0, y: 0, rotate: 0, transition: { duration: 0 } },
  exit: { opacity: 0, transition: { duration: 0 } },
};
