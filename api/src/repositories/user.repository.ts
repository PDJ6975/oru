import { prisma } from "../db/prisma.js";

export const getSessionByTokenHash = async (tokenHash: string) => {
  return await prisma.session.findUnique({
    where: {
      tokenHash,
    },
  });
};

export const getUserById = async (userId: number) => {
  return await prisma.user.findUnique({
    where: {
      id: userId,
    },
  });
};

// TODO: Si el usuario tiene token en disco, no bienvenida, e.o.c, bienvenida y se llama al create sesión con el name
export const createUser = (tokenHash: string, name: string) => {
  return prisma.user.create({
    data: {
      name,
      sessions: {
        create: {
          tokenHash,
        },
      },
    },
    include: {
      sessions: true,
    },
  });
};
